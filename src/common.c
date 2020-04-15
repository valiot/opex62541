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

static const char response_id = 'r';

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
void handle_test(void *data, int data_type, int data_len)
{

}