/*
 *  Copyright 2016 Frank Hunleth
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#define CLIENT


#include "common.h"
#include "open62541.h"
#include "erlcmd.h"
#include <string.h>
#ifdef __APPLE__
#include <mach/clock.h>
#include <mach/mach.h>
#else
#include <time.h>
#endif

const char response_id = 'r';

#ifdef DEBUG
FILE *log_location;
#endif

/**
 * @return a monotonic timestamp in milliseconds
 */
uint64_t current_time()
{
#ifdef __APPLE__
    clock_serv_t cclock;
    mach_timespec_t mts;

    host_get_clock_service(mach_host_self(), SYSTEM_CLOCK, &cclock);
    clock_get_time(cclock, &mts);
    mach_port_deallocate(mach_task_self(), cclock);

    return ((uint64_t) mts.tv_sec) * 1000 + mts.tv_nsec / 1000000;
#else
    // Linux and Windows support clock_gettime()
    struct timespec tp;
    int rc = clock_gettime(CLOCK_MONOTONIC, &tp);
    if (rc < 0)
        errx(EXIT_FAILURE, "clock_gettime failed?");

    return ((uint64_t) tp.tv_sec) * 1000 + tp.tv_nsec / 1000000;
#endif
}


/*************/
/* Toolchain */
/*************/

void reverse(char s[])
{
    int i, j;
    char c;

    for (i = 0, j = strlen(s)-1; i<j; i++, j--) {
        c = s[i];
        s[i] = s[j];
        s[j] = c;
    }
}

void itoa(int n, char s[])
{
    int i, sign;

    if ((sign = n) < 0)  /* record sign */
        n = -n;          /* make n positive */
    i = 0;
    do {       /* generate digits in reverse order */
        s[i++] = n % 10 + '0';   /* get next digit */
    } while ((n /= 10) > 0);     /* delete it */
    if (sign < 0)
        s[i++] = '-';
    s[i] = '\0';
    reverse(s);
}

/*******************************/
/* Common Open62541 assemblers */
/*******************************/

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

/*****************************/
/* Elixir Message assemblers */
/*****************************/

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



void encode_client_config(char *resp, int *resp_index, void *data)
{
    ei_encode_map_header(resp, resp_index, 3);
    ei_encode_binary(resp, resp_index, "timeout", 7);
    ei_encode_long(resp, resp_index,((UA_ClientConfig *)data)->timeout);
    
    ei_encode_binary(resp, resp_index, "secureChannelLifeTime", 21);
    ei_encode_long(resp, resp_index,((UA_ClientConfig *)data)->secureChannelLifeTime);
    
    ei_encode_binary(resp, resp_index, "requestedSessionTimeout", 23);
    ei_encode_long(resp, resp_index,((UA_ClientConfig *)data)->requestedSessionTimeout);
}

void encode_server_on_the_network_struct(char *resp, int *resp_index, void *data, int data_len)
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

void encode_application_description_struct(char *resp, int *resp_index, void *data, int data_len)
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

void encode_endpoint_description_struct(char *resp, int *resp_index, void *data, int data_len)
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

void encode_server_config(char *resp, int *resp_index, void *data)
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
 * @brief Send data back to Elixir in form of {:ok, data}
 */
void send_data_response(void *data, int data_type, int data_len)
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

        case 11: //UA_ServerConfig
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
void send_error_response(const char *reason)
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

/**
 * @brief Send :ok back to Elixir
 */
void send_ok_response()
{
    char resp[256];
    int resp_index = sizeof(uint16_t); // Space for payload size
    resp[resp_index++] = response_id;
    ei_encode_version(resp, &resp_index);
    ei_encode_atom(resp, &resp_index, "ok");
    erlcmd_send(resp, resp_index);
}

// https://open62541.org/doc/current/statuscodes.html?highlight=error
void send_opex_response(uint32_t reason)
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

/*****************************/
/* Common Open62541 handlers */
/*****************************/

void handle_test(void *entity, bool entity_type, const char *req, int *req_index)
{
    if(entity_type)
    {

    }
    else
    {
        UA_ServerConfig *config = UA_Server_getConfig((UA_Server *)entity);
        send_data_response(config, 11, 0);
    }
     
}

/******************************/
/* Node Addition and Deletion */
/******************************/

/* 
 *  Add a new variable node to the server. 
 */
void handle_add_variable_node(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 5)
        errx(EXIT_FAILURE, ":handle_add_variable_node requires a 5-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);
    UA_NodeId type_definition = assemble_node_id(req, req_index);

    UA_VariableAttributes vAttr = UA_VariableAttributes_default;
    
    if(entity_type)
        retval = UA_Client_addVariableNode((UA_Client *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, type_definition, vAttr, NULL);
    else
        retval = UA_Server_addVariableNode((UA_Server *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, type_definition, vAttr, NULL, NULL);

    UA_NodeId_clear(&requested_new_node_id);
    UA_NodeId_clear(&parent_node_id);
    UA_NodeId_clear(&reference_type_node_id);
    UA_QualifiedName_clear(&browse_name);
    UA_NodeId_clear(&type_definition);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Add a new variable type node to the server.(client must send {0,0,0} for type_definition),
 */
void handle_add_variable_type_node(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 5)
        errx(EXIT_FAILURE, ":handle_add_variable_type_node requires a 5-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);
    UA_NodeId type_definition = assemble_node_id(req, req_index);

    UA_VariableTypeAttributes vtAttr = UA_VariableTypeAttributes_default;
    
    if(entity_type)
        retval = UA_Client_addVariableTypeNode((UA_Client *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, vtAttr, NULL);
    else
        retval = UA_Server_addVariableTypeNode((UA_Server *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, type_definition, vtAttr, NULL, NULL);

    UA_NodeId_clear(&requested_new_node_id);
    UA_NodeId_clear(&parent_node_id);
    UA_NodeId_clear(&reference_type_node_id);
    UA_QualifiedName_clear(&browse_name);
    UA_NodeId_clear(&type_definition);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Add a new object node to the server. 
 */
void handle_add_object_node(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 5)
        errx(EXIT_FAILURE, ":handle_add_object_node requires a 5-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);
    UA_NodeId type_definition = assemble_node_id(req, req_index);

    UA_ObjectAttributes oAttr = UA_ObjectAttributes_default;
    
    if(entity_type)
        retval = UA_Client_addObjectNode((UA_Client *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, type_definition, oAttr, NULL);
    else
        retval = UA_Server_addObjectNode((UA_Server *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, type_definition, oAttr, NULL, NULL);

    UA_NodeId_clear(&requested_new_node_id);
    UA_NodeId_clear(&parent_node_id);
    UA_NodeId_clear(&reference_type_node_id);
    UA_QualifiedName_clear(&browse_name);
    UA_NodeId_clear(&type_definition);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Add a new object type node to the server. 
 */
void handle_add_object_type_node(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 4)
        errx(EXIT_FAILURE, ":handle_add_object_type_node requires a 4-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);

    UA_ObjectTypeAttributes otAttr = UA_ObjectTypeAttributes_default;
    
    if(entity_type)
        retval = UA_Client_addObjectTypeNode((UA_Client *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, otAttr, NULL);
    else
        retval = UA_Server_addObjectTypeNode((UA_Server *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, otAttr, NULL, NULL);
    
    UA_NodeId_clear(&requested_new_node_id);
    UA_NodeId_clear(&parent_node_id);
    UA_NodeId_clear(&reference_type_node_id);
    UA_QualifiedName_clear(&browse_name);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Add a new view node to the server. 
 */
void handle_add_view_node(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 4)
        errx(EXIT_FAILURE, ":handle_add_view_node requires a 4-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);

    UA_ViewAttributes vwAttr = UA_ViewAttributes_default;
    
    if(entity_type)
        retval = UA_Client_addViewNode((UA_Client *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, vwAttr, NULL);
    else
        retval = UA_Server_addViewNode((UA_Server *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, vwAttr, NULL, NULL);

    UA_NodeId_clear(&requested_new_node_id);
    UA_NodeId_clear(&parent_node_id);
    UA_NodeId_clear(&reference_type_node_id);
    UA_QualifiedName_clear(&browse_name);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Add a new reference type node to the server. 
 */
void handle_add_reference_type_node(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 4)
        errx(EXIT_FAILURE, ":handle_add_reference_type_node requires a 4-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);

    UA_ReferenceTypeAttributes rtAttr = UA_ReferenceTypeAttributes_default;
    
    if(entity_type)
        retval = UA_Client_addReferenceTypeNode((UA_Client *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, rtAttr, NULL);
    else
        retval = UA_Server_addReferenceTypeNode((UA_Server *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, rtAttr, NULL, NULL);

    UA_NodeId_clear(&requested_new_node_id);
    UA_NodeId_clear(&parent_node_id);
    UA_NodeId_clear(&reference_type_node_id);
    UA_QualifiedName_clear(&browse_name);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Add a new data type node to the server. 
 */
void handle_add_data_type_node(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 4)
        errx(EXIT_FAILURE, ":handle_add_data_type_node requires a 4-tuple, term_size = %d", term_size);
    
    UA_NodeId requested_new_node_id = assemble_node_id(req, req_index);
    UA_NodeId parent_node_id = assemble_node_id(req, req_index);
    UA_NodeId reference_type_node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);

    UA_DataTypeAttributes dtAttr = UA_DataTypeAttributes_default;
    
    if(entity_type)
        retval = UA_Client_addDataTypeNode((UA_Client *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, dtAttr, NULL);
    else
        retval = UA_Server_addDataTypeNode((UA_Server *)entity, requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, dtAttr, NULL, NULL);

    UA_NodeId_clear(&requested_new_node_id);
    UA_NodeId_clear(&parent_node_id);
    UA_NodeId_clear(&reference_type_node_id);
    UA_QualifiedName_clear(&browse_name);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Delete a reference in the server. 
 */
void handle_delete_reference(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

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
    
    if(entity_type)
        retval = UA_Client_deleteReference((UA_Client *)entity, source_id, reference_type_id, (UA_Boolean)is_forward, target_id, (UA_Boolean)delete_bidirectional);
    else
        retval = UA_Server_deleteReference((UA_Server *)entity, source_id, reference_type_id, (UA_Boolean)is_forward, target_id, (UA_Boolean)delete_bidirectional);

    UA_NodeId_clear(&source_id);
    UA_NodeId_clear(&reference_type_id);
    UA_ExpandedNodeId_clear(&target_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Delete a node in the server. 
 */
void handle_delete_node(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_StatusCode retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_delete_node requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);

    int delete_references;
    ei_decode_boolean(req, req_index, &delete_references);
    
    if(entity_type)
        retval = UA_Client_deleteNode((UA_Client *)entity, node_id, (UA_Boolean)delete_references);
    else
        retval = UA_Server_deleteNode((UA_Server *)entity, node_id, (UA_Boolean)delete_references);

    UA_NodeId_clear(&node_id);

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
void handle_write_node_browse_name(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_browse_name requires a 2-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);
    UA_QualifiedName browse_name = assemble_qualified_name(req, req_index);
    
    UA_StatusCode retval = UA_Server_writeBrowseName((UA_Server *)entity, node_id, browse_name);

    UA_NodeId_clear(&node_id);
    UA_QualifiedName_clear(&browse_name);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change the display name of a node in the server. 
 */
void handle_write_node_display_name(void *entity, bool entity_type, const char *req, int *req_index)
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
    
    UA_StatusCode retval = UA_Server_writeDescription((UA_Server *)entity, node_id, display_name);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change description of a node in the server. 
 */
void handle_write_node_description(void *entity, bool entity_type, const char *req, int *req_index)
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
    
    UA_StatusCode retval = UA_Server_writeDescription((UA_Server *)entity, node_id, description);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Write Mask' of a node in the server. 
 */
void handle_write_node_write_mask(void *entity, bool entity_type, const char *req, int *req_index)
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
    
    UA_StatusCode retval = UA_Server_writeWriteMask((UA_Server *)entity, node_id, (UA_UInt32) write_mask);
    
    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Is Abstract' of a node in the server. 
 */
void handle_write_node_is_abstract(void *entity, bool entity_type, const char *req, int *req_index)
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
    
    UA_StatusCode retval = UA_Server_writeIsAbstract((UA_Server *)entity, node_id, (UA_Boolean)is_abstract);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Inverse name' of a node in the server. 
 */
void handle_write_node_inverse_name(void *entity, bool entity_type, const char *req, int *req_index)
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
    
    UA_StatusCode retval = UA_Server_writeInverseName((UA_Server *)entity, node_id, inverse_name);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'data type' of a node in the server. 
 */
void handle_write_node_data_type(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_write_node_data_type requires a 3-tuple, term_size = %d", term_size);
    
    UA_NodeId node_id = assemble_node_id(req, req_index);
    UA_NodeId data_type_node_id = assemble_node_id(req, req_index);

    UA_StatusCode retval = UA_Server_writeDataType((UA_Server *)entity, node_id, data_type_node_id);

    UA_NodeId_clear(&node_id);
    UA_NodeId_clear(&data_type_node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Value Rank' of a node in the server. 
 */
void handle_write_node_value_rank(void *entity, bool entity_type, const char *req, int *req_index)
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
    
    UA_StatusCode retval = UA_Server_writeValueRank((UA_Server *)entity, node_id, (UA_UInt32) value_rank);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Access Level' of a node in the server. 
 */
void handle_write_node_access_level(void *entity, bool entity_type, const char *req, int *req_index)
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
    
    UA_StatusCode retval = UA_Server_writeAccessLevel((UA_Server *)entity, node_id, (UA_Byte) access_level);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Minimum Sampling Interval' of a node in the server. 
 */
void handle_write_node_minimum_sampling_interval(void *entity, bool entity_type, const char *req, int *req_index)
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
    
    UA_StatusCode retval = UA_Server_writeAccessLevel((UA_Server *)entity, node_id, (UA_Double) sampling_interval);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Historizing' of a node in the server. 
 */
void handle_write_node_historizing(void *entity, bool entity_type, const char *req, int *req_index)
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
    
    UA_StatusCode retval = UA_Server_writeHistorizing((UA_Server *)entity, node_id, (UA_Boolean)historizing);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'Excutable' of a node in the server. 
 */
void handle_write_node_executable(void *entity, bool entity_type, const char *req, int *req_index)
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
    
    UA_StatusCode retval = UA_Server_writeHistorizing((UA_Server *)entity, node_id, (UA_Boolean)executable);

    UA_NodeId_clear(&node_id);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Change 'value' of a node in the server.
 *  BUG String is allocated in memory 
 */
void handle_write_node_value(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_NodeId node_id_arg_1;
    UA_NodeId node_id_arg_2;
    UA_ExpandedNodeId expanded_node_id_arg_1;
    UA_QualifiedName qualified_name;

    char *arg1 = (char *)malloc(0);
    char *arg2 = (char *)malloc(0);


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

        case UA_TYPES_SBYTE:
        {
            long sbyte_data;
            if (ei_decode_long(req, req_index, &sbyte_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_SByte data = sbyte_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_SBYTE]);
        }
        break;

        case UA_TYPES_BYTE:
        {
            unsigned long byte_data;
            if (ei_decode_ulong(req, req_index, &byte_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_SByte data = byte_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_BYTE]);
        }
        break;

        case UA_TYPES_INT16:
        {
            long int16_data;
            if (ei_decode_long(req, req_index, &int16_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_Int16 data = int16_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_INT16]);
        }
        break;

        case UA_TYPES_UINT16:
        {
            unsigned long uint16_data;
            if (ei_decode_ulong(req, req_index, &uint16_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_UInt16 data = uint16_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_UINT16]);
        }
        break;

        case UA_TYPES_INT32:
        {
            long int32_data;
            if (ei_decode_long(req, req_index, &int32_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_Int32 data = int32_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_INT32]);
        }
        break;

        case UA_TYPES_UINT32:
        {
            unsigned long uint32_data;
            if (ei_decode_ulong(req, req_index, &uint32_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_UInt32 data = uint32_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_UINT32]);
        }
        break;

        case UA_TYPES_INT64:
        {
            long long int64_data;
            if (ei_decode_longlong(req, req_index, &int64_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_Int64 data = int64_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_INT64]);
        }
        break;

        case UA_TYPES_UINT64:
        {
            unsigned long long uint64_data;
            if (ei_decode_ulonglong(req, req_index, &uint64_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_UInt64 data = uint64_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_UINT64]);
        }
        break;

        case UA_TYPES_FLOAT:
        {
            double float_data;
            if (ei_decode_double(req, req_index, &float_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_Float data = (float) float_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_FLOAT]);
        }
        break;

        case UA_TYPES_DOUBLE:
        {
            double double_data;
            if (ei_decode_double(req, req_index, &double_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_Double data = double_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_DOUBLE]);
        }
        break;

        case UA_TYPES_STRING:
        {
            if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
                errx(EXIT_FAILURE, "Invalid string (size)");

            arg1 = (char *)malloc(term_size + 1);
    
            long binary_len;
            if (ei_decode_binary(req, req_index, arg1, &binary_len) < 0) 
                errx(EXIT_FAILURE, "Invalid string");

            arg1[binary_len] = '\0';

            UA_String data = UA_STRING(arg1);

            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_STRING]);
        }
        break;

        case UA_TYPES_DATETIME:
        {
            long long date_time_data;
            if (ei_decode_longlong(req, req_index, &date_time_data) < 0) {
                send_error_response("einval");
                return;
            }
            
            UA_DateTime data = date_time_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_DATETIME]);
        }
        break;

        case UA_TYPES_GUID:
        {
            UA_Guid guid;

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
                    term_size > (int) sizeof(guid.data4) ||
                    ei_decode_binary(req, req_index, guid.data4, &binary_len) < 0) 
                errx(EXIT_FAILURE, "Invalid GUID data4 %d >= %d, %d", term_size,(int) sizeof(guid.data4), term_size >= (int) sizeof(guid.data4));
            
            guid.data1 = guid_data1;
            guid.data2 = guid_data2;
            guid.data3 = guid_data3;

            UA_Variant_setScalar(&value, &guid, &UA_TYPES[UA_TYPES_GUID]);
        }
        break;

        case UA_TYPES_BYTESTRING:
        {
            if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
                errx(EXIT_FAILURE, "Invalid byte_string (size)");

            
            arg1 = (char *)malloc(term_size + 1);
    
            long binary_len;
            if (ei_decode_binary(req, req_index, arg1, &binary_len) < 0) 
                errx(EXIT_FAILURE, "Invalid byte_string");

            arg1[binary_len] = '\0';

            UA_ByteString data = UA_BYTESTRING(arg1);

            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_BYTESTRING]);
        }
        break;

        case UA_TYPES_XMLELEMENT:
        {
            if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
                errx(EXIT_FAILURE, "Invalid xml (size)");

            arg1 = (char *)malloc(term_size + 1);
    
            long binary_len;
            if (ei_decode_binary(req, req_index, arg1, &binary_len) < 0) 
                errx(EXIT_FAILURE, "Invalid xml");

            arg1[binary_len] = '\0';

            UA_XmlElement data = UA_STRING(arg1);

            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_XMLELEMENT]);
        }
        break;

        case UA_TYPES_NODEID:
        {
            node_id_arg_1 = assemble_node_id(req, req_index);
            UA_Variant_setScalar(&value, &node_id_arg_1, &UA_TYPES[UA_TYPES_NODEID]);
        }
        break;

        case UA_TYPES_EXPANDEDNODEID:
        {
            expanded_node_id_arg_1 = assemble_expanded_node_id(req, req_index);
            UA_Variant_setScalar(&value, &expanded_node_id_arg_1, &UA_TYPES[UA_TYPES_EXPANDEDNODEID]);
        }
        break;

        case UA_TYPES_STATUSCODE:
        {
            unsigned long status_code_data;
            if (ei_decode_ulong(req, req_index, &status_code_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_StatusCode data = status_code_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_STATUSCODE]);
        }
        break;

        case UA_TYPES_QUALIFIEDNAME:
        {
            qualified_name = assemble_qualified_name(req, req_index);
            UA_Variant_setScalar(&value, &qualified_name, &UA_TYPES[UA_TYPES_QUALIFIEDNAME]);
        }
        break;

        case UA_TYPES_LOCALIZEDTEXT:
        {
            if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
                term_size != 2)
                errx(EXIT_FAILURE, ":handle_write_node_value requires a 2-tuple, term_size = %d", term_size);

            // locale
            if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
                errx(EXIT_FAILURE, "Invalid locale (size)");

            arg1 = (char *)malloc(term_size + 1);
    
            long binary_len;
            if (ei_decode_binary(req, req_index, arg1, &binary_len) < 0) 
                errx(EXIT_FAILURE, "Invalid locale");

            arg1[binary_len] = '\0';

            // text
            if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
                errx(EXIT_FAILURE, "Invalid text (size)");

            arg2 = (char *)malloc(term_size + 1);
    
            if (ei_decode_binary(req, req_index, arg2, &binary_len) < 0) 
                errx(EXIT_FAILURE, "Invalid text");

            arg2[binary_len] = '\0';

            UA_LocalizedText data = UA_LOCALIZEDTEXT(arg1, arg2);

            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_LOCALIZEDTEXT]);
        }
        break;

        //UA_TYPES_EXTENSIONOBJECT:

        //UA_TYPES_DATAVALUE

        //UA_TYPES_VARIANT

        //UA_TYPES_DIAGNOSTICINFO:

        case UA_TYPES_SEMANTICCHANGESTRUCTUREDATATYPE:
        {
            if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
                term_size != 2)
                errx(EXIT_FAILURE, ":handle_write_node_value requires a 2-tuple, term_size = %d", term_size);

            node_id_arg_1 = assemble_node_id(req, req_index);
            node_id_arg_2 = assemble_node_id(req, req_index);
            UA_SemanticChangeStructureDataType data;
            data.affected = node_id_arg_1;
            data.affectedType = node_id_arg_2;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_SEMANTICCHANGESTRUCTUREDATATYPE]);
        }
        break;

        case UA_TYPES_TIMESTRING:
        {
             if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
                errx(EXIT_FAILURE, "Invalid time_string (size)");

            arg1 = (char *)malloc(term_size + 1);
    
            long binary_len;
            if (ei_decode_binary(req, req_index, arg1, &binary_len) < 0) 
                errx(EXIT_FAILURE, "Invalid time_string");

            arg1[binary_len] = '\0';

            UA_TimeString data = UA_STRING(arg1);
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_TIMESTRING]);
        }
        break;

        //UA_TYPES_VIEWATTRIBUTES

        case UA_TYPES_UADPNETWORKMESSAGECONTENTMASK:
        {
            unsigned long content_mask_data;
            if (ei_decode_ulong(req, req_index, &content_mask_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_UadpNetworkMessageContentMask data = content_mask_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_UADPNETWORKMESSAGECONTENTMASK]);
        }
        break;

        case UA_TYPES_XVTYPE:
        {
            if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
                term_size != 2)
                errx(EXIT_FAILURE, ":handle_write_node_value (UA_TYPES_XVTYPE) requires a 2-tuple, term_size = %d", term_size);

            double float_data;
            if (ei_decode_double(req, req_index, &float_data) < 0) {
                send_error_response("einval");
                return;
            }

            double double_data;
            if (ei_decode_double(req, req_index, &double_data) < 0) {
                send_error_response("einval");
                return;
            }

            UA_XVType data;

            data.value = (float) float_data;
            data.x = double_data;
            
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_XVTYPE]);
        }
        break;

        case UA_TYPES_ELEMENTOPERAND:
        {
            unsigned long element_operand_data;
            if (ei_decode_ulong(req, req_index, &element_operand_data) < 0) {
                send_error_response("einval");
                return;
            }
            UA_ElementOperand data ;
            data.index = element_operand_data;
            UA_Variant_setScalar(&value, &data, &UA_TYPES[UA_TYPES_ELEMENTOPERAND]);
        }
        break;


        default:
            errx(EXIT_FAILURE, ":handle_write_node_value invalid data_type = %ld", data_type);
        break;
    }
    
    UA_StatusCode retval = UA_Server_writeValue((UA_Server *)entity, node_id, value);

    free(arg1);
    free(arg2);
    UA_NodeId_clear(&node_id);
    UA_NodeId_clear(&node_id_arg_1);
    UA_NodeId_clear(&node_id_arg_2);
    if(data_type == UA_TYPES_EXPANDEDNODEID)
        UA_ExpandedNodeId_clear(&expanded_node_id_arg_1);
    
    if(data_type == UA_TYPES_QUALIFIEDNAME)
        UA_QualifiedName_clear(&qualified_name);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}