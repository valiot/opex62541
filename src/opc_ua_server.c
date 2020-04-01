
#include <open62541.h>
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <poll.h>
#include <stdio.h>
#include "erlcmd.h"

static const char response_id = 'r';

int server_pid;

pthread_t server_tid;
pthread_attr_t server_attr;
UA_Boolean running = true;

UA_Server *server;


static UA_Boolean
allowAddNode(UA_Server *server, UA_AccessControl *ac,
             const UA_NodeId *sessionId, void *sessionContext,
             const UA_AddNodesItem *item)  {return UA_TRUE;}

static UA_Boolean
allowAddReference(UA_Server *server, UA_AccessControl *ac,
                  const UA_NodeId *sessionId, void *sessionContext,
                  const UA_AddReferencesItem *item) {return UA_TRUE;}

static UA_Boolean
allowDeleteNode(UA_Server *server, UA_AccessControl *ac,
                const UA_NodeId *sessionId, void *sessionContext,
                const UA_DeleteNodesItem *item) {return UA_FALSE;} // Do not allow deletion from client

static UA_Boolean
allowDeleteReference(UA_Server *server, UA_AccessControl *ac,
                     const UA_NodeId *sessionId, void *sessionContext,
                     const UA_DeleteReferencesItem *item) {return UA_TRUE;}

void* server_runner(void* arg)
{
	UA_StatusCode retval = UA_Server_run(server, &running);
    if(retval != UA_STATUSCODE_GOOD) {
        errx(EXIT_FAILURE, "Unexpected Server error %s", UA_StatusCode_name(retval));
    }
    return NULL;
}

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

static void encode_server_config(char *resp, int *resp_index, void *data)
{   
    ei_encode_map_header(resp, resp_index, 4);
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

UA_NodeId assemble_node_id(const char *req, int *req_index)
{
    enum node_type{Numeric, String, GUID, ByteString}; 

    int term_size;
    int term_type;
    UA_NodeId node_id = UA_NODEID_NULL;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, "assemble_node_id requires a 3-tuple, term_size = %d", term_size);
    
    unsigned long node_type;
    if (ei_decode_ulong(req, req_index, &node_type) < 0)
        errx(EXIT_FAILURE, "Invalid node_type");

    unsigned long ns_index;
    if (ei_decode_ulong(req, req_index, &ns_index) < 0)
        errx(EXIT_FAILURE, "Invalid ns_index");

    switch (node_type)
    {
        case Numeric:
            {
                unsigned long identifier;
                if (ei_decode_ulong(req, req_index, &identifier) < 0) 
                    errx(EXIT_FAILURE, "Invalid identifier");

                node_id = UA_NODEID_NUMERIC(ns_index, (UA_UInt32)identifier);
            }
        break;

        case String:
            {
                if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
                    errx(EXIT_FAILURE, "Invalid bytestring (size)");

                char *node_string;
                node_string = (char *)malloc(term_size + 1);
                long binary_len;
                if (ei_decode_binary(req, req_index, node_string, &binary_len) < 0) 
                    errx(EXIT_FAILURE, "Invalid bytestring");

                node_string[binary_len] = '\0';

                // if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
                // term_size != 2)
                //     errx(EXIT_FAILURE, "Invalid string, term_size = %d", term_size);

                // unsigned long str_len;
                // if (ei_decode_ulong(req, req_index, &str_len) < 0)
                //     errx(EXIT_FAILURE, "Invalid string length");

                // char node_string[str_len + 1];
                // long binary_len;
                // if (ei_get_type(req, req_index, &term_type, &term_size) < 0 ||
                //         term_type != ERL_BINARY_EXT ||
                //         term_size >= (int) sizeof(node_string) ||
                //         ei_decode_binary(req, req_index, node_string, &binary_len) < 0) {
                // errx(EXIT_FAILURE, "Invalid node_string");
                // }
                // node_string[binary_len] = '\0';

                node_id = UA_NODEID_STRING(ns_index, node_string);
            }
        break;

        case GUID:
            {   
                UA_Guid node_guid;

                if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
                term_size != 4)
                    errx(EXIT_FAILURE, "Invalid string, term_size = %d", term_size);

                unsigned long guid_data1;
                if (ei_decode_ulong(req, req_index, &guid_data1) < 0)
                    errx(EXIT_FAILURE, "Invalid GUID data1");
                
                unsigned long guid_data2;
                if (ei_decode_ulong(req, req_index, &guid_data2) < 0)
                    errx(EXIT_FAILURE, "Invalid GUID data2");
                
                unsigned long guid_data3;
                if (ei_decode_ulong(req, req_index, &guid_data3) < 0)
                    errx(EXIT_FAILURE, "Invalid GUID data3");

                // UA_Byte guid_data4[9];
                long binary_len;
                if (ei_get_type(req, req_index, &term_type, &term_size) < 0 ||
                        term_type != ERL_BINARY_EXT ||
                        term_size > (int) sizeof(node_guid.data4) ||
                        ei_decode_binary(req, req_index, node_guid.data4, &binary_len) < 0) 
                    errx(EXIT_FAILURE, "Invalid GUID data4 %d >= %d, %d", term_size,(int) sizeof(node_guid.data4), term_size >= (int) sizeof(node_guid.data4));
                
                node_guid.data1 = guid_data1;
                node_guid.data2 = guid_data2;
                node_guid.data3 = guid_data3;
                //node_guid.data4[0] = guid_data4[0];
                
                node_id = UA_NODEID_GUID(ns_index, node_guid);
            }
        break;
        
        case ByteString:
            {
                if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
                    errx(EXIT_FAILURE, "Invalid bytestring (size)");

                char *node_bytestring;
                node_bytestring = (char *)malloc(term_size + 1);
                long binary_len;
                if (ei_decode_binary(req, req_index, node_bytestring, &binary_len) < 0) 
                    errx(EXIT_FAILURE, "Invalid bytestring");

                node_bytestring[binary_len] = '\0';

                node_id = UA_NODEID_BYTESTRING(ns_index, node_bytestring);    
            }
        break;
        
        default:
            errx(EXIT_FAILURE, "Unknown node_type");
        break;
    }

    return node_id;
}

UA_ExpandedNodeId assemble_expanded_node_id(const char *req, int *req_index)
{
    enum node_type{Numeric, String, GUID, ByteString}; 

    int term_size;
    int term_type;
    UA_ExpandedNodeId node_id = UA_EXPANDEDNODEID_NULL;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, "assemble_node_id requires a 3-tuple, term_size = %d", term_size);
    
    unsigned long node_type;
    if (ei_decode_ulong(req, req_index, &node_type) < 0)
        errx(EXIT_FAILURE, "Invalid node_type");

    unsigned long ns_index;
    if (ei_decode_ulong(req, req_index, &ns_index) < 0)
        errx(EXIT_FAILURE, "Invalid ns_index");

    switch (node_type)
    {
        case Numeric:
            {
                unsigned long identifier;
                if (ei_decode_ulong(req, req_index, &identifier) < 0) 
                    errx(EXIT_FAILURE, "Invalid identifier");

                node_id = UA_EXPANDEDNODEID_NUMERIC(ns_index, (UA_UInt32)identifier);
            }
        break;

        case String:
            {
                if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
                    errx(EXIT_FAILURE, "Invalid bytestring (size)");

                char *node_string;
                node_string = (char *)malloc(term_size + 1);
                long binary_len;
                if (ei_decode_binary(req, req_index, node_string, &binary_len) < 0) 
                    errx(EXIT_FAILURE, "Invalid bytestring");

                node_string[binary_len] = '\0';
                // if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
                // term_size != 2)
                //     errx(EXIT_FAILURE, "Invalid string, term_size = %d", term_size);

                // unsigned long str_len;
                // if (ei_decode_ulong(req, req_index, &str_len) < 0)
                //     errx(EXIT_FAILURE, "Invalid string length");

                // char node_string[str_len + 1];
                // long binary_len;
                // if (ei_get_type(req, req_index, &term_type, &term_size) < 0 ||
                //         term_type != ERL_BINARY_EXT ||
                //         term_size >= (int) sizeof(node_string) ||
                //         ei_decode_binary(req, req_index, node_string, &binary_len) < 0) {
                // errx(EXIT_FAILURE, "Invalid node_string");
                // }
                // node_string[binary_len] = '\0';

                node_id = UA_EXPANDEDNODEID_STRING(ns_index, node_string);
            }
        break;

        case GUID:
            {   
                UA_Guid node_guid;

                if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
                term_size != 4)
                    errx(EXIT_FAILURE, "Invalid string, term_size = %d", term_size);

                unsigned long guid_data1;
                if (ei_decode_ulong(req, req_index, &guid_data1) < 0)
                    errx(EXIT_FAILURE, "Invalid GUID data1");
                
                unsigned long guid_data2;
                if (ei_decode_ulong(req, req_index, &guid_data2) < 0)
                    errx(EXIT_FAILURE, "Invalid GUID data2");
                
                unsigned long guid_data3;
                if (ei_decode_ulong(req, req_index, &guid_data3) < 0)
                    errx(EXIT_FAILURE, "Invalid GUID data3");

                // UA_Byte guid_data4[9];
                long binary_len;
                if (ei_get_type(req, req_index, &term_type, &term_size) < 0 ||
                        term_type != ERL_BINARY_EXT ||
                        term_size > (int) sizeof(node_guid.data4) ||
                        ei_decode_binary(req, req_index, node_guid.data4, &binary_len) < 0) 
                    errx(EXIT_FAILURE, "Invalid GUID data4 %d >= %d, %d", term_size,(int) sizeof(node_guid.data4), term_size >= (int) sizeof(node_guid.data4));
                
                node_guid.data1 = guid_data1;
                node_guid.data2 = guid_data2;
                node_guid.data3 = guid_data3;
                
                node_id = UA_EXPANDEDNODEID_STRING_GUID(ns_index, node_guid);
            }
        break;
        
        case ByteString:
            {
                if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
                    errx(EXIT_FAILURE, "Invalid bytestring (size)");

                char *node_bytestring;
                node_bytestring = (char *)malloc(term_size + 1);
                long binary_len;
                if (ei_decode_binary(req, req_index, node_bytestring, &binary_len) < 0) 
                    errx(EXIT_FAILURE, "Invalid bytestring");

                node_bytestring[binary_len] = '\0';

                node_id = UA_EXPANDEDNODEID_BYTESTRING(ns_index, node_bytestring);    
            }
        break;
        
        default:
            errx(EXIT_FAILURE, "Unknown node_type");
        break;
    }

    return node_id;
}

UA_QualifiedName assemble_qualified_name(const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_QualifiedName qualified_name;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, "assemble_qualified_name requires a 2-tuple, term_size = %d", term_size);

    unsigned long ns_index;
    if (ei_decode_ulong(req, req_index, &ns_index) < 0)
        errx(EXIT_FAILURE, "Invalid ns_index");

    // String
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid bytestring (size)");

    char *node_qualified_name_str;
    node_qualified_name_str = (char *)malloc(term_size + 1);
    long binary_len;
    if (ei_decode_binary(req, req_index, node_qualified_name_str, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid bytestring");

    node_qualified_name_str[binary_len] = '\0';

    return UA_QUALIFIEDNAME(ns_index, node_qualified_name_str);
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

/* 
*   sets the server port. 
*/
static void handle_set_users_and_passwords(const char *req, int *req_index)
{
    int list_arity;
    int tuple_arity;
    int term_type;
    int term_size;

    if(ei_decode_list_header(req, req_index, &list_arity) < 0)
        errx(EXIT_FAILURE, ":handle_set_users_and_passwords has an empty list");

    UA_UsernamePasswordLogin logins[list_arity];
    
    for(size_t i = 0; i < list_arity; i++) {
        if(ei_decode_tuple_header(req, req_index, &tuple_arity) < 0 || tuple_arity != 4)
            errx(EXIT_FAILURE, ":handle_set_users_and_passwords requires a 4-tuple, term_size = %d", tuple_arity);

        unsigned long str_len;
        if (ei_decode_ulong(req, req_index, &str_len) < 0) {
            send_error_response("einval");
            return;
        }

        char username[str_len + 1];
        long binary_len;
        if (ei_get_type(req, req_index, &term_type, &term_size) < 0 ||
                term_type != ERL_BINARY_EXT ||
                term_size >= (int) sizeof(username) ||
                ei_decode_binary(req, req_index, username, &binary_len) < 0) {
            // The name is almost certainly too long, so report that it
            // doesn't exist.
            send_error_response("enoent");
            return;
        }
        username[binary_len] = '\0';

        if (ei_decode_ulong(req, req_index, &str_len) < 0) {
            send_error_response("einval");
            return;
        }

        char password[str_len + 1];
        if (ei_get_type(req, req_index, &term_type, &term_size) < 0 ||
                term_type != ERL_BINARY_EXT ||
                term_size >= (int) sizeof(password) ||
                ei_decode_binary(req, req_index, password, &binary_len) < 0) {
            // The name is almost certainly too long, so report that it
            // doesn't exist.
            send_error_response("enoent");
            return;
        }
        password[binary_len] = '\0';

        logins[i].username = UA_STRING(username);
        logins[i].password = UA_STRING(password);
    }

    UA_ServerConfig *config = UA_Server_getConfig(server);
    config->accessControl.clear(&config->accessControl);
    UA_StatusCode retval = UA_AccessControl_default(config, false, &config->securityPolicies[config->securityPoliciesSize-1].policyUri, list_arity, logins);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    config->accessControl.allowAddNode = allowAddNode;
    config->accessControl.allowAddReference = allowAddReference;
    config->accessControl.allowDeleteNode = allowDeleteNode;
    config->accessControl.allowDeleteReference = allowDeleteReference;

    send_ok_response();
}

static void handle_start_server(const char *req, int *req_index)
{
    pthread_create(&server_tid, NULL, server_runner, NULL);
    // server_pid = fork();
    // if(server_pid == 0)
    // {
    //     //child process
    //     UA_StatusCode retval = UA_Server_run(server, &running);
    //     if(retval != UA_STATUSCODE_GOOD) {
    //         errx(EXIT_FAILURE, "Unexpected Server error %s", UA_StatusCode_name(retval));
    //     }
    //     return;
    // }

    send_ok_response();
}

static void handle_stop_server(const char *req, int *req_index)
{
    running = false;
    send_ok_response();
}

/******************************/
/* Node Addition and Deletion */
/******************************/

/* 
 *  Add a new namespace to the server. Returns the index of the new namespace 
 */
static void handle_add_namespace(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_add_namespace requires a 2-tuple, term_size = %d", term_size);

    unsigned long str_len;
    if (ei_decode_ulong(req, req_index, &str_len) < 0) {
        send_error_response("einval");
        return;
    }

    char namespace[str_len + 1];
    long binary_len;
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 ||
            term_type != ERL_BINARY_EXT ||
            term_size >= (int) sizeof(namespace) ||
            ei_decode_binary(req, req_index, namespace, &binary_len) < 0) {
        // The name is almost certainly too long, so report that it
        // doesn't exist.
        send_error_response("enoent");
        return;
    }
    namespace[binary_len] = '\0';

    UA_Int16 *ns_id = UA_Server_addNamespace(server, namespace);

    send_data_response(&ns_id, 2, 0);
}

/* 
 *  Add a new variable node to the server. 
 */
static void handle_add_variable_node(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 5)
        errx(EXIT_FAILURE, ":handle_add_variable_node requires a 5-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);
    UA_NodeId type_definition = assemble_node_id(req, req_index);

    UA_VariableAttributes vAttr = UA_VariableAttributes_default;
    
    UA_StatusCode retval = UA_Server_addVariableNode(server, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, type_definition, vAttr, NULL, NULL);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Add a new variable type node to the server. 
 */
static void handle_add_variable_type_node(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 5)
        errx(EXIT_FAILURE, ":handle_add_variable_type_node requires a 5-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);
    UA_NodeId type_definition = assemble_node_id(req, req_index);

    UA_VariableTypeAttributes vtAttr = UA_VariableTypeAttributes_default;
    
    UA_StatusCode retval = UA_Server_addVariableTypeNode(server, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, type_definition, vtAttr, NULL, NULL);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Add a new object node to the server. 
 */
static void handle_add_object_node(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 5)
        errx(EXIT_FAILURE, ":handle_add_object_node requires a 5-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);
    UA_NodeId type_definition = assemble_node_id(req, req_index);

    UA_ObjectAttributes oAttr = UA_ObjectAttributes_default;
    
    UA_StatusCode retval = UA_Server_addObjectNode(server, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, type_definition, oAttr, NULL, NULL);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Add a new object type node to the server. 
 */
static void handle_add_object_type_node(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 4)
        errx(EXIT_FAILURE, ":handle_add_object_type_node requires a 4-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);

    UA_ObjectTypeAttributes otAttr = UA_ObjectTypeAttributes_default;
    
    UA_StatusCode retval = UA_Server_addObjectTypeNode(server, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, otAttr, NULL, NULL);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    UA_NodeId_clear(&requested_new_node_id);
    UA_NodeId_clear(&parent_node_id);
    UA_NodeId_clear(&reference_type_node_id);
    UA_QualifiedName_clear(&browse_name);

    send_ok_response();
}

/* 
 *  Add a new view node to the server. 
 */
static void handle_add_view_node(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 4)
        errx(EXIT_FAILURE, ":handle_add_view_node requires a 4-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);

    UA_ViewAttributes vwAttr = UA_ViewAttributes_default;
    
    UA_StatusCode retval = UA_Server_addViewNode(server, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, vwAttr, NULL, NULL);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Add a new reference type node to the server. 
 */
static void handle_add_reference_type_node(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 4)
        errx(EXIT_FAILURE, ":handle_add_reference_type_node requires a 4-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);

    UA_ReferenceTypeAttributes rtAttr = UA_ReferenceTypeAttributes_default;
    
    UA_StatusCode retval = UA_Server_addReferenceTypeNode(server, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, rtAttr, NULL, NULL);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Add a new data type node to the server. 
 */
static void handle_add_data_type_node(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 4)
        errx(EXIT_FAILURE, ":handle_add_data_type_node requires a 4-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);

    UA_DataTypeAttributes dtAttr = UA_DataTypeAttributes_default;
    
    UA_StatusCode retval = UA_Server_addDataTypeNode(server, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, dtAttr, NULL, NULL);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Add a new reference to the server. 
 */
static void handle_add_reference(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 4)
        errx(EXIT_FAILURE, ":handle_add_reference requires a 4-tuple, term_size = %d", term_size);
    
    UA_NodeId source_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_id = assemble_node_id(req, req_index);
    UA_ExpandedNodeId target_id = assemble_expanded_node_id(req, req_index);

    int is_forward;
    ei_decode_boolean(req, req_index, &is_forward);
    
    UA_StatusCode retval =  UA_Server_addReference(server, source_id, reference_type_id, target_id, (UA_Boolean)is_forward);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Delete a reference in the server. 
 */
static void handle_delete_reference(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 5)
        errx(EXIT_FAILURE, ":handle_delete_reference requires a 5-tuple, term_size = %d", term_size);
    
    UA_NodeId source_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_id = assemble_node_id(req, req_index);
    UA_ExpandedNodeId target_id = assemble_expanded_node_id(req, req_index);
    
    int is_forward;
    ei_decode_boolean(req, req_index, &is_forward);

    int delete_bidirectional;
    ei_decode_boolean(req, req_index, &delete_bidirectional);
    
    UA_StatusCode retval =  UA_Server_deleteReference(server, source_id, reference_type_id, (UA_Boolean)is_forward, target_id, (UA_Boolean)delete_bidirectional);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Delete a node in the server. 
 */
static void handle_delete_node(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_delete_node requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    int delete_references;
    ei_decode_boolean(req, req_index, &delete_references);
    
    UA_StatusCode retval = UA_Server_deleteNode(server, node_id, (UA_Boolean)delete_references);
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
 *  Change the browse name of a node in the server. 
 */
static void handle_write_node_browse_name(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_browse_name requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);
    
    UA_StatusCode retval = UA_Server_writeBrowseName(server, node_id, browse_name);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change the display name of a node in the server. 
 */
static void handle_write_node_display_name(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":handle_write_node_display_name requires a 3-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    // locale
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid locale (size)");
    
    char locale[term_size + 1];
    long binary_len;
    if (ei_decode_binary(req, req_index, locale, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid locale");

    locale[binary_len + 1] = '\0';

    // name_str
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid name_str (size)");
    
    char name_str[term_size + 1];
    if (ei_decode_binary(req, req_index, name_str, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid name_str");

    name_str[binary_len + 1] = '\0';

    UA_LocalizedText display_name =  UA_LOCALIZEDTEXT(locale, name_str);
    
    UA_StatusCode retval = UA_Server_writeDescription(server, node_id, display_name);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change description of a node in the server. 
 */
static void handle_write_node_description(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":handle_write_node_description requires a 3-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    // locale
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid locale (size)");
    
    char locale[term_size + 1];
    long binary_len;
    if (ei_decode_binary(req, req_index, locale, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid locale");

    locale[binary_len + 1] = '\0';

    // description_str
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid description_str (size)");
    
    char description_str[term_size + 1];
    if (ei_decode_binary(req, req_index, description_str, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid description_str");

    description_str[binary_len + 1] = '\0';

    UA_LocalizedText description =  UA_LOCALIZEDTEXT(locale, description_str);
    
    UA_StatusCode retval = UA_Server_writeDescription(server, node_id, description);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Write Mask' of a node in the server. 
 */
static void handle_write_node_write_mask(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_write_mask requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    // write_mask
    unsigned long write_mask;
    if (ei_decode_ulong(req, req_index, &write_mask) < 0) {
        send_error_response("einval");
        return;
    }
    
    UA_StatusCode retval = UA_Server_writeWriteMask(server, node_id, (UA_UInt32) write_mask);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Is Abstract' of a node in the server. 
 */
static void handle_write_node_is_abstract(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_is_abstract requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    // write_mask
    int is_abstract;
    if (ei_decode_boolean(req, req_index, &is_abstract) < 0) {
        send_error_response("einval");
        return;
    }
    
    UA_StatusCode retval = UA_Server_writeIsAbstract(server, node_id, (UA_Boolean)is_abstract);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Inverse name' of a node in the server. 
 */
static void handle_write_node_inverse_name(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":handle_write_node_inverse_name requires a 3-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    // locale
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid locale (size)");
    
    char locale[term_size + 1];
    long binary_len;
    if (ei_decode_binary(req, req_index, locale, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid locale");

    locale[binary_len + 1] = '\0';

    // inverse_name_str
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid inverse_name_str (size)");
    
    char inverse_name_str[term_size + 1];
    if (ei_decode_binary(req, req_index, inverse_name_str, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid inverse_name_str");

    inverse_name_str[binary_len + 1] = '\0';

    UA_LocalizedText inverse_name =  UA_LOCALIZEDTEXT(locale, inverse_name_str);
    
    UA_StatusCode retval = UA_Server_writeInverseName(server, node_id, inverse_name);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'data type' of a node in the server. 
 */
static void handle_write_node_data_type(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_data_type requires a 3-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);
    UA_NodeId data_type_node_id = assemble_node_id(req, req_index);

    
    UA_StatusCode retval = UA_Server_writeDataType(server, node_id, data_type_node_id);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Value Rank' of a node in the server. 
 */
static void handle_write_node_value_rank(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_value_rank requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    // value_range
    unsigned long value_rank;
    if (ei_decode_ulong(req, req_index, &value_rank) < 0) {
        send_error_response("einval");
        return;
    }
    
    UA_StatusCode retval = UA_Server_writeValueRank(server, node_id, (UA_UInt32) value_rank);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Access Level' of a node in the server. 
 */
static void handle_write_node_access_level(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_access_level requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    // value_range
    unsigned long access_level;
    if (ei_decode_ulong(req, req_index, &access_level) < 0) {
        send_error_response("einval");
        return;
    }
    
    UA_StatusCode retval = UA_Server_writeAccessLevel(server, node_id, (UA_Byte) access_level);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Minimum Sampling Interval' of a node in the server. 
 */
static void handle_write_node_minimum_sampling_interval(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_minimum_sampling_interval requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    // value_range
    double sampling_interval;
    if (ei_decode_double(req, req_index, &sampling_interval) < 0) {
        send_error_response("einval");
        return;
    }
    
    UA_StatusCode retval = UA_Server_writeAccessLevel(server, node_id, (UA_Double) sampling_interval);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Historizing' of a node in the server. 
 */
static void handle_write_node_historizing(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_historizing requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    // write_mask
    int historizing;
    if (ei_decode_boolean(req, req_index, &historizing) < 0) {
        send_error_response("einval");
        return;
    }
    
    UA_StatusCode retval = UA_Server_writeHistorizing(server, node_id, (UA_Boolean)historizing);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Excutable' of a node in the server. 
 */
static void handle_write_node_executable(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_executable requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    // write_mask
    int executable;
    if (ei_decode_boolean(req, req_index, &executable) < 0) {
        send_error_response("einval");
        return;
    }
    
    UA_StatusCode retval = UA_Server_writeHistorizing(server, node_id, (UA_Boolean)executable);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'value' of a node in the server. 
 */
static void handle_write_node_value(const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":handle_write_node_value requires a 3-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    unsigned long data_type;
    if (ei_decode_ulong(req, req_index, &data_type) < 0) {
        send_error_response("einval");
        return;
    }

    UA_Variant value;
    switch (data_type)
    {
        case UA_TYPES_BOOLEAN:
        {
            int boolean_data;
            if (ei_decode_boolean(req, req_index, &boolean_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_Boolean data = boolean_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_BOOLEAN]);
        }
        break;
    
        default:
            errx(EXIT_FAILURE, ":handle_write_node_value invalid data_type = %ld", data_type);
        break;
    }
    
    UA_StatusCode retval = UA_Server_writeValue(server, node_id, value);
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
    // Reading and Writing Node Attributes
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
    // configuration & lifecycle functions
    {"get_server_config", handle_get_server_config},
    {"set_default_server_config", handle_set_default_server_config},
    {"set_hostname", handle_set_hostname},
    {"set_port", handle_set_port},
    {"set_users", handle_set_users_and_passwords},
    {"start_server", handle_start_server},
    {"stop_server", handle_stop_server},
    // Node Addition and Deletion
    {"add_namespace", handle_add_namespace},
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
    running = false;
    UA_Server_delete(server); 
}