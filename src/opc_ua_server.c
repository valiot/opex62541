
#include "open62541.h"
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <poll.h>
#include <stdio.h>
#include "erlcmd.h"
#include "common.h"

//int server_pid;

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

/***************************************/
/* Configuration & Lifecycle Functions */
/***************************************/
/* 
*   Gets the server configuration. (nThreads, applications, endpoints).
*/
static void handle_get_server_config(void *entity, bool entity_type, const char *req, int *req_index)
{
    UA_ServerConfig *config = UA_Server_getConfig(server);
    send_data_response(config, 11, 0);
}

/* 
*   sets the server open62541 defaults configuration. 
*/
static void handle_set_default_server_config(void *entity, bool entity_type, const char *req, int *req_index)
{
    UA_ServerConfig_setDefault(UA_Server_getConfig(server));
    send_ok_response();
}

/* 
*   sets the server hostname. 
*/
static void handle_set_hostname(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid hostname (size)");

    char host_name[term_size + 1];
    long binary_len;
    if (ei_decode_binary(req, req_index, host_name, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid hostname");
    host_name[binary_len] = '\0';

    UA_String hostname;
    UA_String_init(&hostname);
    hostname.length = binary_len;
    hostname.data = (UA_Byte *) host_name;

    UA_ServerConfig_setCustomHostname(UA_Server_getConfig(server), hostname);

    send_ok_response();
}

/* 
*   sets the server port. 
*/
static void handle_set_port(void *entity, bool entity_type, const char *req, int *req_index)
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
*   Sets the server port. 
*   TODO: free usernames/password allocated array.
*/
static void handle_set_users_and_passwords(void *entity, bool entity_type, const char *req, int *req_index)
{
    int list_arity;
    int tuple_arity;
    int term_type;
    int term_size;

    if(ei_decode_list_header(req, req_index, &list_arity) < 0)
        errx(EXIT_FAILURE, ":handle_set_users_and_passwords has an empty list");

    UA_UsernamePasswordLogin logins[list_arity];
    
    for(size_t i = 0; i < list_arity; i++) {
        if(ei_decode_tuple_header(req, req_index, &tuple_arity) < 0 || tuple_arity != 2)
            errx(EXIT_FAILURE, ":handle_set_users_and_passwords requires a 2-tuple, term_size = %d", tuple_arity);

        if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
            errx(EXIT_FAILURE, "Invalid hostname (size)");

        char *username;
        username = (char *)malloc(term_size + 1);
        long binary_len;
        if (ei_decode_binary(req, req_index, username, &binary_len) < 0) 
            errx(EXIT_FAILURE, "Invalid hostname");
        username[binary_len] = '\0';

        if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
            errx(EXIT_FAILURE, "Invalid hostname (size)");

        char *password;
        password = (char *)malloc(term_size + 1);
        if (ei_decode_binary(req, req_index, password, &binary_len) < 0) 
            errx(EXIT_FAILURE, "Invalid hostname");
        password[binary_len] = '\0';

        logins[i].username = UA_STRING(username);
        logins[i].password = UA_STRING(password);
    }

    UA_ServerConfig *config = UA_Server_getConfig(server);
    //config->accessControl.clear(&config->accessControl);
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

static void handle_start_server(void *entity, bool entity_type, const char *req, int *req_index)
{
    running = true;
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

static void handle_stop_server(void *entity, bool entity_type, const char *req, int *req_index)
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
void handle_add_namespace(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid bytestring (size)");

    char namespace[term_size + 1];
    long binary_len;
    if (ei_decode_binary(req, req_index, namespace, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid namespace");

    namespace[binary_len] = '\0';

    UA_Int16 *ns_id = UA_Server_addNamespace(server, namespace);

    send_data_response(&ns_id, 2, 0);
}

/* 
 *  Add a new reference to the server. 
 */
void handle_add_reference(void *entity, bool entity_type, const char *req, int *req_index)
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
            rh->handler(server, 0, req, &req_index);
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