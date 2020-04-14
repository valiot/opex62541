
#include <open62541.h>
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <stdio.h>
#include "erlcmd.h"

static const char response_id = 'r';

UA_Client *client;

/*****************************/
/* Elixir Message assemblers */
/*****************************/

// https://open62541.org/doc/current/statuscodes.html?highlight=error
static void send_opex_response(uint32_t reason)
{
    const char *status_code = UA_StatusCode_name(reason);
    char resp[256];
    int resp_index = sizeof(uint16_t); // Space for payload size
    resp[resp_index++] = response_id;
    ei_encode_version(resp, &resp_index);
    ei_encode_tuple_header(resp, &resp_index, 2);
    ei_encode_atom(resp, &resp_index, "error");
    ei_encode_binary(resp, &resp_index, status_code, strlen(status_code));
    erlcmd_send(resp, resp_index);
}


static void encode_client_config(char *resp, int *resp_index, void *data)
{
    ei_encode_map_header(resp, resp_index, 3);
    ei_encode_binary(resp, resp_index, "timeout", 7);
    ei_encode_long(resp, resp_index,((UA_ClientConfig *)data)->timeout);
    
    ei_encode_binary(resp, resp_index, "secureChannelLifeTime", 21);
    ei_encode_long(resp, resp_index,((UA_ClientConfig *)data)->secureChannelLifeTime);
    
    ei_encode_binary(resp, resp_index, "requestedSessionTimeout", 23);
    ei_encode_long(resp, resp_index,((UA_ClientConfig *)data)->requestedSessionTimeout);
}

static void encode_server_on_the_network_struct(char *resp, int *resp_index, void *data, int data_len)
{
    UA_ServerOnNetwork *serverOnNetwork = ((UA_ServerOnNetwork *)data);

    ei_encode_list_header(resp, resp_index, data_len);

    for(size_t i = 0; i < data_len; i++) {
        UA_ServerOnNetwork *server = &serverOnNetwork[i];
        ei_encode_map_header(resp, resp_index, 4);
        
        ei_encode_binary(resp, resp_index, "server_name", 11);
        ei_encode_binary(resp, resp_index, server->serverName.data, (int)server->serverName.length);

        ei_encode_binary(resp, resp_index, "record_id", 9);
        ei_encode_long(resp, resp_index, (int)server->recordId);

        ei_encode_binary(resp, resp_index, "discovery_url", 13);
        ei_encode_binary(resp, resp_index, server->discoveryUrl.data, (int)server->discoveryUrl.length);

        ei_encode_binary(resp, resp_index, "capabilities", 12);

        ei_encode_list_header(resp, resp_index, server->serverCapabilitiesSize);
        for(size_t j = 0; j < server->serverCapabilitiesSize; j++) {
            ei_encode_binary(resp, resp_index, server->serverCapabilities[j].data, (int) server->serverCapabilities[j].length);
        }
        if(server->serverCapabilitiesSize)
            ei_encode_empty_list(resp, resp_index);
    }
    if(data_len)
        ei_encode_empty_list(resp, resp_index);
}

static void encode_application_description_struct(char *resp, int *resp_index, void *data, int data_len)
{
    UA_ApplicationDescription *applicationDescriptionArray = ((UA_ApplicationDescription *)data);

    ei_encode_list_header(resp, resp_index, data_len);

    for(size_t i = 0; i < data_len; i++) {
        UA_ApplicationDescription *description = &applicationDescriptionArray[i];
        ei_encode_map_header(resp, resp_index, 6);
        
        ei_encode_binary(resp, resp_index, "server", 6);
        ei_encode_binary(resp, resp_index, description->applicationUri.data, (int) description->applicationUri.length);

        ei_encode_binary(resp, resp_index, "name", 4);
        ei_encode_binary(resp, resp_index, description->applicationName.text.data, (int) description->applicationName.text.length);

        ei_encode_binary(resp, resp_index, "application_uri", 15);
        ei_encode_binary(resp, resp_index, description->applicationUri.data, (int) description->applicationUri.length);

        ei_encode_binary(resp, resp_index, "product_uri", 11);
        ei_encode_binary(resp, resp_index, description->productUri.data, (int) description->productUri.length);

        ei_encode_binary(resp, resp_index, "type", 4);
        switch(description->applicationType) {
            case UA_APPLICATIONTYPE_SERVER:
                ei_encode_binary(resp, resp_index, "server", 6);
                break;
            case UA_APPLICATIONTYPE_CLIENT:
                ei_encode_binary(resp, resp_index, "client", 6);
                break;
            case UA_APPLICATIONTYPE_CLIENTANDSERVER:
                ei_encode_binary(resp, resp_index, "client_and_server", 17);
                break;
            case UA_APPLICATIONTYPE_DISCOVERYSERVER:
                ei_encode_binary(resp, resp_index, "discovery_server", 16);
                break;
            default:
                ei_encode_binary(resp, resp_index, "unknown", 7);
        }

        ei_encode_binary(resp, resp_index, "discovery_url", 13);
        ei_encode_list_header(resp, resp_index, description->discoveryUrlsSize);
        for(size_t j = 0; j < description->discoveryUrlsSize; j++) {
            ei_encode_binary(resp, resp_index, description->discoveryUrls[j].data, (int) description->discoveryUrls[j].length);
        }
        if(description->discoveryUrlsSize)
            ei_encode_empty_list(resp, resp_index);
    }
    if(data_len)
        ei_encode_empty_list(resp, resp_index);
}

static void encode_endpoint_description_struct(char *resp, int *resp_index, void *data, int data_len)
{
    UA_EndpointDescription *endpointArray = ((UA_EndpointDescription *)data);

    ei_encode_list_header(resp, resp_index, data_len);

    for(size_t i = 0; i < data_len; i++) {
        UA_EndpointDescription *endpoint = &endpointArray[i];
        ei_encode_map_header(resp, resp_index, 5);

        ei_encode_binary(resp, resp_index, "endpoint_url", 12);
        ei_encode_binary(resp, resp_index, endpoint->endpointUrl.data, (int) endpoint->endpointUrl.length);

        ei_encode_binary(resp, resp_index, "transport_profile_uri", 21);
        ei_encode_binary(resp, resp_index, endpoint->transportProfileUri.data, (int) endpoint->transportProfileUri.length);

        ei_encode_binary(resp, resp_index, "security_mode", 13);
        switch(endpoint->securityMode) {
            case UA_APPLICATIONTYPE_SERVER:
                ei_encode_binary(resp, resp_index, "invalid", 7);
                break;
            case UA_APPLICATIONTYPE_CLIENT:
                ei_encode_binary(resp, resp_index, "none", 4);
                break;
            case UA_APPLICATIONTYPE_CLIENTANDSERVER:
                ei_encode_binary(resp, resp_index, "sign", 4);
                break;
            case UA_APPLICATIONTYPE_DISCOVERYSERVER:
                ei_encode_binary(resp, resp_index, "sign_and_encrypt", 16);
                break;
            default:
                ei_encode_binary(resp, resp_index, "unknown", 7);
        }

        ei_encode_binary(resp, resp_index, "security_profile_uri", 20);
        ei_encode_binary(resp, resp_index, endpoint->securityPolicyUri.data, (int) endpoint->securityPolicyUri.length);

        ei_encode_binary(resp, resp_index, "security_level", 14);
        ei_encode_long(resp, resp_index, endpoint->securityLevel);
    }
    if(data_len)
        ei_encode_empty_list(resp, resp_index);
}

/**
 * @brief Send :ok back to Elixir
 */
static void send_ok_response()
{
    char resp[256];
    int resp_index = sizeof(uint16_t); // Space for payload size
    resp[resp_index++] = response_id;
    ei_encode_version(resp, &resp_index);
    ei_encode_atom(resp, &resp_index, "ok");
    erlcmd_send(resp, resp_index);
}

/**
 * @brief Send data back to Elixir in form of {:ok, data}
 */
static void send_data_response(void *data, int data_type, int data_len)
{
    char resp[1024];
    char version[5];
    char r_len = 1;
    long i_struct;
    int resp_index = sizeof(uint16_t); // Space for payload size
    resp[resp_index++] = response_id;
    ei_encode_version(resp, &resp_index);
    ei_encode_tuple_header(resp, &resp_index, 2);
    ei_encode_atom(resp, &resp_index, "ok");

    switch(data_type)
    {
        case 1: //signed (long)
            ei_encode_long(resp, &resp_index,*(int32_t *)data);
        break;

        case 2: //unsigned (long)
            ei_encode_ulong(resp, &resp_index,*(uint32_t *)data);
        break;

        case 3: //strings
            ei_encode_string(resp, &resp_index, data);
        break;

        case 4: //doubles
            ei_encode_double(resp, &resp_index, *(double *)data);
        break;

        case 5: //arrays (byte type)
            ei_encode_binary(resp, &resp_index, data, data_len);
        break;

        case 6: //atom
            ei_encode_atom(resp, &resp_index, data);
        break;

        case 7: //UA_ClientConfig
            encode_client_config(resp, &resp_index, data);
        break;

        case 8: //UA_ServerOnNetwork
            encode_server_on_the_network_struct(resp, &resp_index, data, data_len);
        break;

        case 9: //UA_ApplicationDescription
            encode_application_description_struct(resp, &resp_index, data, data_len);
        break;

        case 10: //UA_EndpointDescription
            encode_endpoint_description_struct(resp, &resp_index, data, data_len);
        break;

        default:
            errx(EXIT_FAILURE, "data_type error");
        break;
    }

    erlcmd_send(resp, resp_index);
}

/**
 * @brief Send a response of the form {:error, reason}
 *
 * @param reason is an error reason (sended back as an atom)
 */
static void send_error_response(const char *reason)
{
    char resp[256];
    int resp_index = sizeof(uint16_t); // Space for payload size
    resp[resp_index++] = response_id;
    ei_encode_version(resp, &resp_index);
    ei_encode_tuple_header(resp, &resp_index, 2);
    ei_encode_atom(resp, &resp_index, "error");
    ei_encode_atom(resp, &resp_index, reason);
    erlcmd_send(resp, resp_index);
}

static void handle_test(const char *req, int *req_index)
{
    send_ok_response();    
}

/***************************************/
/* Configuration & Lifecycle Functions */
/***************************************/

/**
 *  This is function allows to configure the client. 
*/
static void handle_set_client_config(const char *req, int *req_index)
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
static void handle_get_client_config(const char *req, int *req_index)
{
    UA_ClientConfig *config = UA_Client_getConfig(client);
    send_data_response(config, 7, 0);
}

/*
 * Gets the current client connection state. 
*/
static void handle_get_client_state(const char *req, int *req_index)
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
static void handle_reset_client(const char *req, int *req_index)
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
static void handle_connect_client_by_url(const char *req, int *req_index)
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
static void handle_connect_client_by_username(const char *req, int *req_index)
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
static void handle_connect_client_no_session(const char *req, int *req_index)
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
static void handle_disconnect_client(const char *req, int *req_index)
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
static void handle_find_servers_on_network(const char *req, int *req_index)
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
static void handle_find_servers(const char *req, int *req_index)
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
static void handle_get_endpoints(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    UA_EndpointDescription *endpointArray = NULL;
        size_t endpointArraySize = 0;

    long binary_len = 0; 

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


/*******************************/
/* Elixir -> C Message Handler */
/*******************************/
struct request_handler {
    const char *name;
    void (*handler)(const char *req, int *req_index);
};

/*  Elixir request handler table
 *  FIXME: Order roughly based on most frequent calls to least (WIP).
 */
static struct request_handler request_handlers[] = {
    {"test", handle_test},
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
            rh->handler(req, &req_index);
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