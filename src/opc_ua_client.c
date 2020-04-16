
#include "open62541.h"
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <stdio.h>
#include "erlcmd.h"
#include "common.h"

static const char response_id = 'r';

UA_Client *client;

/***************************************/
/* Configuration & Lifecycle Functions */
/***************************************/

/**
 *  This is function allows to configure the client. 
*/
static void handle_set_client_config(void *entity, bool entity_type, const char *req, int *req_index)
{
    int i_key;
    int map_size;

    int term_size;
    int term_type;
    unsigned long value;

    UA_ClientConfig *config = UA_Client_getConfig(client);
    UA_ClientConfig_setDefault(config);

    if(ei_decode_map_header(req, req_index, &map_size) < 0)
        errx(EXIT_FAILURE, ":set_client_config inconsistent argument arity = %d", term_size);    
    for(i_key = 0; i_key < map_size; i_key++)
    {
        if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
            errx(EXIT_FAILURE, "Invalid bytestring (size) %d", term_size);

        char key[term_size + 1];
        long binary_len;
        if (ei_decode_binary(req, req_index, key, &binary_len) < 0) 
            errx(EXIT_FAILURE, "Invalid bytestring");
        key[binary_len] = '\0';

        if(!strcmp(key, "timeout"))
        {
            if (ei_decode_ulong(req, req_index, &value) < 0) {
                send_error_response("einval_2");
                return;
            }
            config->timeout = (int)value;
        }
        else if(!strcmp(key, "requestedSessionTimeout"))
        {
            if (ei_decode_ulong(req, req_index, &value) < 0) {
                send_error_response("einval_2");
                return;
            }
            config->requestedSessionTimeout = (int)value;
        }
        else if(!strcmp(key, "secureChannelLifeTime")) 
        {
            if (ei_decode_ulong(req, req_index, &value) < 0) {
                send_error_response("einval_2");
                return;
            }
            config->secureChannelLifeTime = (int)value;
        }
        else
        {
            errx(EXIT_FAILURE, ":set_client_config inconsistent argument arity = %s", key);    
            send_error_response("einval");
            return;
        }
    }

    send_ok_response();
}

/* 
*   Get the client configuration. 
*/
static void handle_get_client_config(void *entity, bool entity_type, const char *req, int *req_index)
{
    UA_ClientConfig *config = UA_Client_getConfig(client);
    send_data_response(config, 7, 0);
}

/*
 * Gets the current client connection state. 
*/
static void handle_get_client_state(void *entity, bool entity_type, const char *req, int *req_index)
{
    UA_ClientState state = UA_Client_getState(client);

    switch(state)
    {
        case UA_CLIENTSTATE_DISCONNECTED:
            send_data_response("Disconnected", 3, 0);
        break;

        case UA_CLIENTSTATE_WAITING_FOR_ACK:
            send_data_response("Wating for ACK", 3, 0);
        break;

        case UA_CLIENTSTATE_CONNECTED:
            send_data_response("Connected", 3, 0);
        break;

        case UA_CLIENTSTATE_SECURECHANNEL:
            send_data_response("Secure Channel", 3, 0);
        break;

        case UA_CLIENTSTATE_SESSION:
            send_data_response("Session", 3, 0);
        break;

        case UA_CLIENTSTATE_SESSION_DISCONNECTED:
            send_data_response("Session disconnected", 3, 0);
        break;

        case UA_CLIENTSTATE_SESSION_RENEWED:
            send_data_response("Session renewed", 3, 0);
        break;
    }
}

/* 
*   Resets a client. 
*/
static void handle_reset_client(void *entity, bool entity_type, const char *req, int *req_index)
{
    UA_Client_reset(client);
    send_ok_response();
}

/************************/
/* Connection Functions */
/************************/

/* Connect to the server by passing only the url.
 *
 * @return Indicates whether the operation succeeded or returns an error code */
static void handle_connect_client_by_url(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid url (size)");

    char url[term_size + 1];
    long binary_len;
    if (ei_decode_binary(req, req_index, url, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid url");
    url[binary_len] = '\0';


    UA_StatusCode retval = UA_Client_connect(client, url);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }
    
    send_ok_response();
}

/* Connect to the server by passing a url, username and password.
 *
 * @return Indicates whether the operation succeeded or returns an error code */
static void handle_connect_client_by_username(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    unsigned long str_len;
    unsigned long binary_len;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 || term_size != 3)
        errx(EXIT_FAILURE, ":connect_client_by_username requires a 3-tuple, term_size = %d", term_size);
    
    // URL
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid url (size)");

    char url[term_size + 1];
    if (ei_decode_binary(req, req_index, url, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid url");
    url[binary_len] = '\0';

    //USER
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid username (size)");

    char username[term_size + 1];
    if (ei_decode_binary(req, req_index, username, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid username");
    username[binary_len] = '\0';

    //PASSWORD
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid password (size)");

    char password[term_size + 1];
    if (ei_decode_binary(req, req_index, password, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid password");
    password[binary_len] = '\0';

    UA_StatusCode retval = UA_Client_connect_username(client, url, username, password);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }
    
    send_ok_response();
}

/* Connect to the server without creating a session.
 *
 * @return Indicates whether the operation succeeded or returns an error code */
static void handle_connect_client_no_session(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    long binary_len = 0; 

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid url (size)");

    char url[term_size + 1];
    if (ei_decode_binary(req, req_index, url, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid url");
    url[binary_len] = '\0';
    
    UA_StatusCode retval = UA_Client_connect_noSession(client, url);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }
    
    send_ok_response();
}

/* Disconnect and close a connection to the selected server.
 *
 * @return Indicates whether the operation succeeded or returns an error code */
static void handle_disconnect_client(void *entity, bool entity_type, const char *req, int *req_index)
{
    
    UA_StatusCode retval = UA_Client_disconnect(client);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }
    
    send_ok_response();
}

/***********************/
/* Discovery Functions */
/***********************/

/* Get a list of all known server in the network. Only supported by LDS servers.
 *
 * @param url to connect (for example "opc.tcp://localhost:4840")
 * @return Indicates whether the operation succeeded or returns an error code */
static void handle_find_servers_on_network(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_ServerOnNetwork *serverOnNetwork = NULL;
    size_t serverOnNetworkSize = 0;

    long binary_len = 0; 

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid url (size)");

    char url[term_size + 1];
    if (ei_decode_binary(req, req_index, url, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid url");
    url[binary_len] = '\0';

    UA_StatusCode retval = UA_Client_findServersOnNetwork(client, url, 0, 0, 0, NULL, &serverOnNetworkSize, &serverOnNetwork);
    
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }
    
    send_data_response(serverOnNetwork, 8, serverOnNetworkSize);
}

/* Gets a list of all registered servers at the given server.
 *
 * @param serverUrl url to connect (for example "opc.tcp://localhost:4840")
 * @return Indicates whether the operation succeeded or returns an error code */
static void handle_find_servers(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;

    UA_ApplicationDescription *applicationDescriptionArray = NULL;
    size_t applicationDescriptionArraySize = 0;

    long binary_len = 0; 

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid url (size)");

    char url[term_size + 1];
    if (ei_decode_binary(req, req_index, url, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid url");
    url[binary_len] = '\0';

    UA_StatusCode retval = UA_Client_findServers(client, url, 0, NULL, 0, NULL, &applicationDescriptionArraySize, &applicationDescriptionArray);
    
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        UA_Array_delete(applicationDescriptionArray, applicationDescriptionArraySize, &UA_TYPES[UA_TYPES_APPLICATIONDESCRIPTION]);
        return;
    }
    
    send_data_response(applicationDescriptionArray, 9, applicationDescriptionArraySize);

    UA_Array_delete(applicationDescriptionArray, applicationDescriptionArraySize, &UA_TYPES[UA_TYPES_APPLICATIONDESCRIPTION]);
}

/* Gets a list of endpoints of a server
 *
 * @param url to connect (for example "opc.tcp://localhost:4840")
 * @return Indicates whether the operation succeeded or returns an error code */
static void handle_get_endpoints(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    long binary_len = 0;

    UA_EndpointDescription *endpointArray = NULL;
    size_t endpointArraySize = 0;

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid url (size)");

    char url[term_size + 1];
    if (ei_decode_binary(req, req_index, url, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid url");
    url[binary_len] = '\0';

    UA_StatusCode retval = UA_Client_getEndpoints(client, url, &endpointArraySize, &endpointArray);
    
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        UA_Array_delete(endpointArray, endpointArraySize, &UA_TYPES[UA_TYPES_ENDPOINTDESCRIPTION]);
        return;
    }
    
    send_data_response(endpointArray, 10, endpointArraySize);
    
    UA_Array_delete(endpointArray, endpointArraySize, &UA_TYPES[UA_TYPES_ENDPOINTDESCRIPTION]);
}

/******************************/
/* Node Addition and Deletion */
/******************************/

/* 
 *  Add a new reference to the server. 
 */
void handle_add_reference(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    long binary_len;
    unsigned long target_node_class;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 6)
        errx(EXIT_FAILURE, ":handle_add_reference requires a 6-tuple, term_size = %d", term_size);
    
    UA_NodeId source_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_id = assemble_node_id(req, req_index);
    UA_ExpandedNodeId target_id = assemble_expanded_node_id(req, req_index);

    int is_forward;
    ei_decode_boolean(req, req_index, &is_forward);

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid target_server_uri (size)");

    char target_server_uri_str[term_size + 1];
    if (ei_decode_binary(req, req_index, target_server_uri_str, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid target_server_uri_str");
    target_server_uri_str[binary_len] = '\0';

    UA_String target_server_uri = UA_STRING(target_server_uri_str);

    if (ei_decode_ulong(req, req_index, &target_node_class) < 0) {
        send_error_response("einval");
        return;
    }

    UA_StatusCode retval = UA_Client_addReference(client, source_id, reference_type_id, (UA_Boolean)is_forward, target_server_uri, target_id, target_node_class);

    UA_NodeId_clear(&source_id);
    UA_NodeId_clear(&reference_type_id);
    UA_ExpandedNodeId_clear(&target_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/*******************************/
/* Elixir -> C Message Handler */
/*******************************/

struct request_handler {
    const char *name;
    void (*handler)(void *entity, bool entity_type, const char *req, int *req_index);
};

/*  Elixir request handler table
 *  FIXME: Order roughly based on most frequent calls to least (WIP).
 */
static struct request_handler request_handlers[] = {
    {"test", handle_test},
    // Reading and Writing Node Attributes ??
    // TODO: Add UA_Server_writeArrayDimensions, 
    {"write_node_value", handle_write_node_value},
    {"write_node_browse_name", handle_write_node_browse_name},
    {"write_node_display_name", handle_write_node_display_name},
    {"write_node_description", handle_write_node_description},
    {"write_node_write_mask", handle_write_node_write_mask},
    {"write_node_is_abstract", handle_write_node_is_abstract},
    {"write_node_inverse_name", handle_write_node_inverse_name},
    {"write_node_data_type", handle_write_node_data_type},
    {"write_node_value_rank", handle_write_node_value_rank},
    {"write_node_access_level", handle_write_node_access_level},
    {"write_node_minimum_sampling_interval", handle_write_node_minimum_sampling_interval},
    {"write_node_historizing", handle_write_node_historizing},
    {"write_node_executable", handle_write_node_executable},
    // lifecycle functions
    {"get_client_state", handle_get_client_state},     
    {"set_client_config", handle_set_client_config},     
    {"get_client_config", handle_get_client_config},     
    {"reset_client", handle_reset_client},
    // connections functions
    {"connect_client_by_url", handle_connect_client_by_url},
    {"connect_client_by_username", handle_connect_client_by_username},     
    {"connect_client_no_session", handle_connect_client_no_session},     
    {"disconnect_client", handle_disconnect_client}, 
    // discovery functions
    {"find_servers_on_network", handle_find_servers_on_network},
    {"find_servers", handle_find_servers}, 
    {"get_endpoints", handle_get_endpoints},
    // Node Addition and Deletion
    {"add_variable_node", handle_add_variable_node},
    {"add_variable_type_node", handle_add_variable_type_node},
    {"add_object_node", handle_add_object_node},
    {"add_object_type_node", handle_add_object_type_node},
    {"add_view_node", handle_add_view_node},
    {"add_reference_type_node", handle_add_reference_type_node},
    {"add_data_type_node", handle_add_data_type_node},
    {"add_reference", handle_add_reference},
    {"delete_reference", handle_delete_reference},
    {"delete_node", handle_delete_node},
    { NULL, NULL }
};

/**
 * @brief Decode and forward requests from Elixir to the appropriate handlers
 * @param req the undecoded request
 * @param cookie
 */
static void handle_elixir_request(const char *req, void *cookie)
{
    (void) cookie;

    // Commands are of the form {Command, Arguments}:
    // { atom(), term() }
    int req_index = sizeof(uint16_t);
    if (ei_decode_version(req, &req_index, NULL) < 0)
        errx(EXIT_FAILURE, "Message version issue?");

    int arity;
    if (ei_decode_tuple_header(req, &req_index, &arity) < 0 ||
            arity != 2)
        errx(EXIT_FAILURE, "expecting {cmd, args} tuple");

    char cmd[MAXATOMLEN];
    if (ei_decode_atom(req, &req_index, cmd) < 0)
        errx(EXIT_FAILURE, "expecting command atom");
    
    //execute all handler
    for (struct request_handler *rh = request_handlers; rh->name != NULL; rh++) {
        if (strcmp(cmd, rh->name) == 0) {
            rh->handler(client, 1, req, &req_index);
            return;
        }
    }
    // no listed function
    errx(EXIT_FAILURE, "unknown command: %s", cmd);
}

int main()
{
    client = UA_Client_new();

    struct erlcmd *handler = malloc(sizeof(struct erlcmd));
    erlcmd_init(handler, handle_elixir_request, NULL);

    for (;;) {
        struct pollfd fdset;

        fdset.fd = STDIN_FILENO;
        fdset.events = POLLIN;
        fdset.revents = 0;

        int timeout = -1; // Wait forever unless told by otherwise
        int rc = poll(&fdset, 1, timeout);

        if (rc < 0) {
            // Retry if EINTR
            if (errno == EINTR)
                continue;

            err(EXIT_FAILURE, "poll");
        }

        if (fdset.revents & (POLLIN | POLLHUP)) {
            if (erlcmd_process(handler))
                break;
        }
    }
    
    /* Disconnects the client internally */
    UA_Client_delete(client); 
}