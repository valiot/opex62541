
#include <open62541.h>
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <stdio.h>
#include "erlcmd.h"

#define LIST_HEAD(name, type)						\
struct name {								\
    struct type *lh_first;	/* first element */			\
}

#define LIST_ENTRY(type)						\
struct {								\
    struct type *le_next;	/* next element */			\
    struct type **le_prev;	/* address of previous next element */	\
}

typedef struct ConnectionEntry {
    UA_Connection connection;
    LIST_ENTRY(ConnectionEntry) pointers;
} ConnectionEntry;

typedef struct {
    const UA_Logger *logger;
    UA_UInt16 port;
    UA_SOCKET serverSockets[FD_SETSIZE];
    UA_UInt16 serverSocketsSize;
    LIST_HEAD(, ConnectionEntry) connections;
} ServerNetworkLayerTCP;

static const char response_id = 'r';

UA_Server *server;

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

static void encode_application_description_struct(char *resp, int *resp_index, void *data, int data_len)
{
    UA_ApplicationDescription *description = ((UA_ApplicationDescription *)data);

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

static void encode_server_network_layers_struct(char *resp, int *resp_index, void *data, int data_len)
{
    UA_ServerNetworkLayer *serverNetworkLayerArray = ((UA_ServerNetworkLayer *)data);


    UA_ServerNetworkLayer serverNetworkLayer = serverNetworkLayerArray[1];
    //errx(EXIT_FAILURE, "error: %ld", ((ServerNetworkLayerTCP *)serverNetworkLayer.handle)->port);
    errx(EXIT_FAILURE, "error: %s", serverNetworkLayer.discoveryUrl.data);

    // ei_encode_list_header(resp, resp_index, data_len);

    // errx(EXIT_FAILURE, "expecting command atom %ld", data_len);

    // for(size_t i = 0; i < data_len; i++) {
    //     UA_ServerNetworkLayer *serverNetworkLayer = &serverNetworkLayerArray[i];
    //     ei_encode_tuple_header(resp, resp_index, 2);
    //     ei_encode_binary(resp, resp_index, serverNetworkLayer->discoveryUrl.data, serverNetworkLayer->discoveryUrl.length);
    //     if (serverNetworkLayer->handle)
    //         ei_encode_long(resp, resp_index, ((ServerNetworkLayerTCP *)serverNetworkLayer->handle)->port);
    //     else
    //         ei_encode_atom(resp, resp_index, "nil");
        
    // }

    if(data_len)
        ei_encode_empty_list(resp, resp_index);
}
TCPClientConnec
static void encode_server_config(char *resp, int *resp_index, void *data)
{   
    ei_encode_map_header(resp, resp_index, 5);
    ei_encode_binary(resp, resp_index, "n_threads", 9);
    ei_encode_long(resp, resp_index,((UA_ServerConfig *)data)->nThreads);
    ei_encode_binary(resp, resp_index, "hostname", 8);
    if (((UA_ServerConfig *)data)->customHostname.length)
        ei_encode_binary(resp, resp_index,((UA_ServerConfig *)data)->customHostname.data, ((UA_ServerConfig *)data)->customHostname.length);
    else
        ei_encode_binary(resp, resp_index, "localhost", 9);
    
    ei_encode_binary(resp, resp_index, "endpoint_description", 20);
    encode_endpoint_description_struct(resp, resp_index, ((UA_ServerConfig *)data)->endpoints, ((UA_ServerConfig *)data)->endpointsSize);

    ei_encode_binary(resp, resp_index, "application_description", 23);
    encode_application_description_struct(resp, resp_index, &((UA_ServerConfig *)data)->applicationDescription, 1);
    
    ei_encode_binary(resp, resp_index, "network_layer", 13);
    errx(EXIT_FAILURE, "error: %s", ((UA_ServerConfig *)data)->networkLayers[1]->discoveryUrl);
    encode_server_network_layers_struct(resp, resp_index, &((UA_ServerConfig *)data)->networkLayers, ((UA_ServerConfig *)data)->networkLayersSize);

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

        case 7: //UA_ServerConfig
            encode_server_config(resp, &resp_index, data);
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
    send_opex_response(UA_STATUSCODE_BADSECURITYCHECKSFAILED);    
}

/***************************************/
/* Configuration & Lifecycle Functions */
/***************************************/
/* 
*   Gets the server configuration. (nThreads, applications, endpoints).
*/
static void handle_get_server_config(const char *req, int *req_index)
{
    UA_ServerConfig *config = UA_Server_getConfig(server);
    send_data_response(config, 7, 0);
}

/* 
*   sets the server open62541 defaults configuration. 
*/
static void handle_set_default_server_config(const char *req, int *req_index)
{
    UA_ServerConfig_setDefault(UA_Server_getConfig(server));
    send_ok_response();
}

/* 
*   sets the server hostname. 
*/
static void handle_set_hostname(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_set_host_name requires a 2-tuple, term_size = %d", term_size);

    unsigned long str_len;
    if (ei_decode_ulong(req, req_index, &str_len) < 0) {
        send_error_response("einval");
        return;
    }

    char host_name[str_len + 1];
    long binary_len;
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 ||
            term_type != ERL_BINARY_EXT ||
            term_size >= (int) sizeof(host_name) ||
            ei_decode_binary(req, req_index, host_name, &binary_len) < 0) {
        // The name is almost certainly too long, so report that it
        // doesn't exist.
        send_error_response("enoent");
        return;
    }
    host_name[binary_len] = '\0';

    UA_String hostname;
    UA_String_init(&hostname);
    hostname.length = str_len;
    hostname.data = (UA_Byte *) host_name;

    UA_ServerConfig_setCustomHostname(UA_Server_getConfig(server), hostname);

    send_ok_response();
}

/* 
*   sets the server port. 
*/
static void handle_set_port(const char *req, int *req_index)
{
    unsigned long port_number;
    if (ei_decode_ulong(req, req_index, &port_number) < 0) {
        send_error_response("einval");
        return;
    }    

    UA_StatusCode retval = UA_ServerConfig_setMinimal(UA_Server_getConfig(server), (UA_Int16) port_number, 0);
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
    void (*handler)(const char *req, int *req_index);
};

/*  Elixir request handler table
 *  FIXME: Order roughly based on most frequent calls to least (WIP).
 */
static struct request_handler request_handlers[] = {
    {"test", handle_test},
    {"get_server_config", handle_get_server_config},
    {"set_default_server_config", handle_set_default_server_config},
    {"set_hostname", handle_set_hostname},
    {"set_port", handle_set_port},
    // lifecycle functions
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
    server = UA_Server_new();

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
    free(handler);
    UA_Server_delete(server); 
}