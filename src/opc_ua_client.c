
#include "open62541.h"
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <stdio.h>
#include <pthread.h>
#include "erlcmd.h"
#include "common.h"

UA_Client *client;

/************************************/
/* Default Client backend callbacks */
/************************************/

static void subscriptionInactivityCallback (UA_Client *client, UA_UInt32 subscription_id, void *subContext) 
{
    send_subscription_timeout_response(&subscription_id, 27, 0);
}

static void deleteSubscriptionCallback(UA_Client *client, UA_UInt32 subscription_id, void *subscriptionContext) 
{
    send_subscription_deleted_response(&subscription_id, 27, 0);
}

static void dataChangeNotificationCallback(UA_Client *client, UA_UInt32 subscription_id, void *subContext, UA_UInt32 monitored_id, void *monContext, UA_DataValue *data) 
{
    switch(data->value.type->typeIndex)
    {
        case UA_TYPES_BOOLEAN:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 0, 0);
        break;

        case UA_TYPES_SBYTE:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 23, 0);
        break;

        case UA_TYPES_BYTE:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 24, 0);
        break;

        case UA_TYPES_INT16:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 25, 0);
        break;
        
        case UA_TYPES_UINT16:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 26, 0);
        break;

        case UA_TYPES_INT32:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 1, 0);
        break;

        case UA_TYPES_UINT32:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 2, 0);
        break;

        case UA_TYPES_INT64:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 15, 0);
        break;

        case UA_TYPES_UINT64:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 16, 0);
        break;

        case UA_TYPES_FLOAT:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 17, 0);
        break;

        case UA_TYPES_DOUBLE:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 4, 0);
        break;

        case UA_TYPES_STRING:
            send_monitored_item_response(&subscription_id, &monitored_id, (*(UA_String *)data->value.data).data, 5, (*(UA_String *)data->value.data).length);
        break;

        case UA_TYPES_DATETIME:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 15, 0);
        break;

        case UA_TYPES_GUID:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 18, 0);
        break;

        case UA_TYPES_BYTESTRING:
            send_monitored_item_response(&subscription_id, &monitored_id, (*(UA_ByteString *)data->value.data).data, 5, (*(UA_ByteString *)data->value.data).length);
        break;

        case UA_TYPES_XMLELEMENT:
            send_monitored_item_response(&subscription_id, &monitored_id, (*(UA_XmlElement *)data->value.data).data, 5, (*(UA_XmlElement *)data->value.data).length);
        break;

        case UA_TYPES_NODEID:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 12, 0);
        break;

        case UA_TYPES_EXPANDEDNODEID:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 19, 0);
        break;

        case UA_TYPES_STATUSCODE:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 20, 0);
        break;

        case UA_TYPES_QUALIFIEDNAME:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 13, 0);
        break;

        case UA_TYPES_LOCALIZEDTEXT:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 14, 0);
        break;

        // TODO: UA_TYPES_EXTENSIONOBJECT
    
        // TODO: UA_TYPES_DATAVALUE

        // TODO: UA_TYPES_VARIANT

        // TODO: UA_TYPES_DIAGNOSTICINFO

        case UA_TYPES_SEMANTICCHANGESTRUCTUREDATATYPE:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 21, 0);
        break;

        case UA_TYPES_TIMESTRING:
            send_monitored_item_response(&subscription_id, &monitored_id, (*(UA_TimeString *)data->value.data).data, 5, (*(UA_TimeString *)data->value.data).length);
        break;

        // TODO: UA_TYPES_VIEWATTRIBUTES

        case UA_TYPES_UADPNETWORKMESSAGECONTENTMASK:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 2, 0);
        break;

        case UA_TYPES_XVTYPE:

            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 22, 0);
        break;

        case UA_TYPES_ELEMENTOPERAND:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 27, 0);
        break;

        default:
            send_monitored_item_response(&subscription_id, &monitored_id, data->value.data, 2, -1);
        break;
    }
}

static void deleteMonitoredItemCallback(UA_Client *client, UA_UInt32 subscription_id, void *subContext, UA_UInt32 monitored_id, void *monContext)
{
    send_monitored_item_delete_response(&subscription_id, &monitored_id);
}
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
        UA_Array_delete(serverOnNetwork, serverOnNetworkSize, &UA_TYPES[UA_TYPES_SERVERONNETWORK]);
        return;
    }
    
    send_data_response(serverOnNetwork, 8, serverOnNetworkSize);

    UA_Array_delete(serverOnNetwork, serverOnNetworkSize, &UA_TYPES[UA_TYPES_SERVERONNETWORK]);
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

/***************************************/
/* Reading and Writing Node Attributes */
/***************************************/

/* 
 *  Change 'data type' of a node in the server. 
 */
void handle_write_node_node_id(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_node_id requires a 3-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);
    UA_NodeId new_node_id = assemble_node_id(req, req_index);

    retval = UA_Client_writeNodeIdAttribute(client, node_id, &new_node_id);

    UA_NodeId_clear(&node_id);
    UA_NodeId_clear(&new_node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'node class' attribute of a node in the server. 
 */
void handle_write_node_node_class(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_node_class requires a 3-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);
    unsigned long node_class;
    
    if (ei_decode_ulong(req, req_index, &node_class) < 0) {
        send_error_response("einval");
        return;
    }

    retval = UA_Client_writeNodeClassAttribute(client, node_id, (UA_NodeClass *) &node_class);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'user_write_mask' attribute of a node in the server. 
 */
void handle_write_node_user_write_mask(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_user_write_mask requires a 3-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);
    unsigned long user_write_mask;
    
    if (ei_decode_ulong(req, req_index, &user_write_mask) < 0) {
        send_error_response("einval");
        return;
    }

    UA_UInt32 ua_user_write_mask = (UA_UInt32) user_write_mask;

    retval = UA_Client_writeUserWriteMaskAttribute(client, node_id, &ua_user_write_mask);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'symmetric' of a node in the server. 
 */
void handle_write_node_symmetric(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_symmetric requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    // write_mask
    int symmetric;
    if (ei_decode_boolean(req, req_index, &symmetric) < 0) {
        send_error_response("einval");
        return;
    }

    UA_Boolean symmetric_bool = symmetric;
    
    retval = UA_Client_writeSymmetricAttribute(client, node_id, &symmetric_bool);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'contains_no_loops' of a node in the server. 
 */
void handle_write_node_contains_no_loops(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_contains_no_loops requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    int contains_no_loops;
    if (ei_decode_boolean(req, req_index, &contains_no_loops) < 0) {
        send_error_response("einval");
        return;
    }

    UA_Boolean contains_no_loops_bool = contains_no_loops;
    
    retval = UA_Client_writeContainsNoLoopsAttribute(client, node_id, &contains_no_loops_bool);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'user_access_level' of a node in the server. 
 */
void handle_write_node_user_access_level(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_user_access_level requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    unsigned long user_access_level;
    if (ei_decode_ulong(req, req_index, &user_access_level) < 0) {
        send_error_response("einval");
        return;
    }
    
    UA_Byte ua_user_access_level = (UA_Byte) user_access_level;

    retval = UA_Client_writeAccessLevelAttribute(client, node_id, &ua_user_access_level);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'user_executable' of a node in the server. 
 */
void handle_write_node_user_executable(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_user_executable requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    int user_executable;
    if (ei_decode_boolean(req, req_index, &user_executable) < 0) {
        send_error_response("einval");
        return;
    }

    UA_Boolean user_executable_bool = user_executable;
    
    retval = UA_Client_writeUserExecutableAttribute(client, node_id, &user_executable_bool);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Reads 'user_write_mask' attribute of a node in the server. 
 */
void handle_read_node_user_write_mask(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;
    UA_UInt32 user_write_mask;

    UA_NodeId node_id = assemble_node_id(req, req_index);

    retval = UA_Client_readUserWriteMaskAttribute(client, node_id, &user_write_mask);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_data_response(&user_write_mask, 27, 0);
}

/* 
 *  Reads 'user_access_level' Attribute from a node. 
 */
void handle_read_node_user_access_level(void *entity, bool entity_type, const char *req, int *req_index)
{
    UA_StatusCode retval;
    UA_Byte user_access_level;
    UA_NodeId node_id = assemble_node_id(req, req_index);

    retval = UA_Client_readUserAccessLevelAttribute(client, node_id, &user_access_level);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_data_response(&user_access_level, 24, 0);
}

/* 
 *  Reads 'user_executable' Attribute from a node. 
 */
void handle_read_node_user_executable(void *entity, bool entity_type, const char *req, int *req_index)
{
    UA_StatusCode retval;
    UA_Boolean user_executable;
    UA_NodeId node_id = assemble_node_id(req, req_index);

    retval = UA_Client_readUserExecutableAttribute(client, node_id, &user_executable);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_data_response(&user_executable, 0, 0);
}


/***********************************************/
/* Subscriptions and Monitored Items functions */
/***********************************************/

/*  Subscriptions
 *
 *  Subscriptions in OPC UA are asynchronous. That is, the client sends several PublishRequests to the server. 
 *  The server returns PublishResponses with notifications. But only when a notification has been generated. 
 *  The client does not wait for the responses and continues normal operations.
 *  Note the difference between Subscriptions and MonitoredItems. Subscriptions are used to report back notifications. 
 *  MonitoredItems are used to generate notifications. Every MonitoredItem is attached to exactly one Subscription. 
 *  And a Subscription can contain many MonitoredItems.
 */

void handle_add_subscription(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_CreateSubscriptionResponse response;

    double publishing_interval;
    if (ei_decode_double(req, req_index, &publishing_interval) < 0) {
        send_error_response("einval");
        return;
    }

    UA_ClientConfig *client_config = UA_Client_getConfig(client);
    client_config->subscriptionInactivityCallback = subscriptionInactivityCallback;

    UA_CreateSubscriptionRequest request = UA_CreateSubscriptionRequest_default();
    request.requestedPublishingInterval = (UA_Double) publishing_interval;
    response = UA_Client_Subscriptions_create(client, request, NULL, NULL, deleteSubscriptionCallback);

    if(response.responseHeader.serviceResult != UA_STATUSCODE_GOOD) {
        send_opex_response(response.responseHeader.serviceResult);
        return;
    }

    send_data_response(&(response.subscriptionId), 27, 0);
}

void handle_delete_subscription(void *entity, bool entity_type, const char *req, int *req_index)
{
    unsigned long subscription_id;
    if (ei_decode_ulong(req, req_index, &subscription_id) < 0) {
        send_error_response("einval");
        return;
    }

    UA_StatusCode retval = UA_Client_Subscriptions_deleteSingle(client, (UA_UInt32) subscription_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/*  Monitored Items
 *
 *  Subscriptions in OPC UA are asynchronous. That is, the client sends several PublishRequests to the server. 
 *  The server returns PublishResponses with notifications. But only when a notification has been generated. 
 *  The client does not wait for the responses and continues normal operations.
 *  Note the difference between Subscriptions and MonitoredItems. Subscriptions are used to report back notifications. 
 *  MonitoredItems are used to generate notifications. Every MonitoredItem is attached to exactly one Subscription. 
 *  And a Subscription can contain many MonitoredItems.
 */

void handle_add_monitored_item(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_MonitoredItemCreateResult monitored_item_response;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":handle_add_monitored_item requires a 3-tuple, term_size = %d", term_size);

    UA_NodeId monitored_node = assemble_node_id(req, req_index);

    unsigned long subscription_id;
    if (ei_decode_ulong(req, req_index, &subscription_id) < 0) {
        send_error_response("einval");
        return;
    }

    double sampling_interval;
    if (ei_decode_double(req, req_index, &sampling_interval) < 0) {
        send_error_response("einval");
        return;
    }
    
    UA_MonitoredItemCreateRequest monitored_item_request = UA_MonitoredItemCreateRequest_default(monitored_node);

    monitored_item_request.requestedParameters.samplingInterval = (UA_Double) sampling_interval;

    monitored_item_response = UA_Client_MonitoredItems_createDataChange(client, subscription_id,
                                                                        UA_TIMESTAMPSTORETURN_BOTH, monitored_item_request,
                                                                        NULL, dataChangeNotificationCallback, deleteMonitoredItemCallback);

    UA_NodeId_clear(&monitored_node);

    if(monitored_item_response.statusCode != UA_STATUSCODE_GOOD) {
        send_opex_response(monitored_item_response.statusCode);
        return;
    }

    send_data_response(&(monitored_item_response.monitoredItemId), 27, 0);
}

void handle_delete_monitored_item(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_delete_monitored_item requires a 2-tuple, term_size = %d", term_size);

    unsigned long subscription_id;
    if (ei_decode_ulong(req, req_index, &subscription_id) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long monitored_item_id;
    if (ei_decode_ulong(req, req_index, &monitored_item_id) < 0) {
        send_error_response("einval");
        return;
    }

    retval = UA_Client_MonitoredItems_deleteSingle(client, (UA_UInt32) subscription_id, (UA_UInt32) monitored_item_id);

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
    // TODO: Add UA_Server_writeArrayDimensions, inverse name (read) 
    {"write_node_value", handle_write_node_value},
    {"read_node_value", handle_read_node_value},
    {"read_node_value_by_data_type", handle_read_node_value_by_data_type},
    {"write_node_node_id", handle_write_node_node_id},
    {"write_node_node_class", handle_write_node_node_class},
    {"write_node_browse_name", handle_write_node_browse_name},
    {"write_node_display_name", handle_write_node_display_name},
    {"write_node_description", handle_write_node_description},
    {"write_node_write_mask", handle_write_node_write_mask},
    {"write_node_user_write_mask", handle_write_node_user_write_mask},
    {"write_node_is_abstract", handle_write_node_is_abstract},
    {"write_node_symmetric", handle_write_node_symmetric},
    {"write_node_inverse_name", handle_write_node_inverse_name},
    {"write_node_contains_no_loops", handle_write_node_contains_no_loops},
    {"write_node_data_type", handle_write_node_data_type},
    {"write_node_value_rank", handle_write_node_value_rank},
    {"write_node_array_dimensions", handle_write_node_array_dimensions},
    {"write_node_access_level", handle_write_node_access_level},
    {"write_node_user_access_level", handle_write_node_user_access_level},
    {"write_node_event_notifier", handle_write_node_event_notifier},
    {"write_node_minimum_sampling_interval", handle_write_node_minimum_sampling_interval},
    {"write_node_historizing", handle_write_node_historizing},
    {"write_node_executable", handle_write_node_executable},
    {"write_node_user_executable", handle_write_node_user_executable},
    {"write_node_blank_array", handle_write_node_blank_array},
    {"read_node_node_id", handle_read_node_node_id},
    {"read_node_node_class", handle_read_node_node_class},
    {"read_node_browse_name", handle_read_node_browse_name},
    {"read_node_display_name", handle_read_node_display_name},
    {"read_node_description", handle_read_node_description},
    {"read_node_write_mask", handle_read_node_write_mask},
    {"read_node_user_write_mask", handle_read_node_user_write_mask},
    {"read_node_is_abstract", handle_read_node_is_abstract},
    {"read_node_symmetric", handle_read_node_symmetric},
    {"read_node_inverse_name", handle_read_node_inverse_name},
    {"read_node_contains_no_loops", handle_read_node_contains_no_loops},
    {"read_node_data_type", handle_read_node_data_type},
    {"read_node_value_rank", handle_read_node_value_rank},
    {"read_node_array_dimensions", handle_read_node_array_dimensions},
    {"read_node_access_level", handle_read_node_access_level},
    {"read_node_user_access_level", handle_read_node_user_access_level},
    {"read_node_minimum_sampling_interval", handle_read_node_minimum_sampling_interval},
    {"read_node_event_notifier", handle_read_node_event_notifier},
    {"read_node_historizing", handle_read_node_historizing},
    {"read_node_executable", handle_read_node_executable},
    {"read_node_user_executable", handle_read_node_user_executable},
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
    // Subscriptions and Monitored Items functions.
    {"add_subscription", handle_add_subscription},
    {"delete_subscription", handle_delete_subscription},
    {"add_monitored_item", handle_add_monitored_item},
    {"delete_monitored_item", handle_delete_monitored_item},
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
            arity != 3)
        errx(EXIT_FAILURE, "expecting {cmd, caller_info, args} tuple");

    char cmd[MAXATOMLEN];
    if (ei_decode_atom(req, &req_index, cmd) < 0)
        errx(EXIT_FAILURE, "expecting command atom");
    
    //execute all handler
    for (struct request_handler *rh = request_handlers; rh->name != NULL; rh++) {
        if (strcmp(cmd, rh->name) == 0) {
            decode_caller_metadata(req, &req_index, cmd);
            rh->handler(client, 1, req, &req_index);
            free_caller_metadata();
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

        if(UA_Client_getState(client) >= UA_CLIENTSTATE_CONNECTED)
        {
            UA_Client_run_iterate(client, 0);
        }
    }
    
    /* Disconnects the client internally */
    UA_Client_delete(client); 
    free(handler);
}