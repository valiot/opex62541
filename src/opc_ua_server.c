
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

typedef struct Users_list{
    size_t list_size;
    char **username;
    char **password;
    UA_UsernamePasswordLogin *logins;  // v1.4.x: Keep logins persistent for UA_AccessControl_default
}User_list;

User_list users_list = {.list_size = 0, .username = NULL, .password = NULL, .logins = NULL};

pthread_t server_tid;
pthread_attr_t server_attr;
UA_Boolean running = true;

UA_Server *server;
UA_Client *discoveryClient;
unsigned long port_number = 4840;

static UA_Boolean
allowAddNode(UA_Server *server, UA_AccessControl *ac,
             const UA_NodeId *sessionId, void *sessionContext,
             const UA_AddNodesItem *item)  {return UA_FALSE;}

static UA_Boolean
allowAddReference(UA_Server *server, UA_AccessControl *ac,
                  const UA_NodeId *sessionId, void *sessionContext,
                  const UA_AddReferencesItem *item) {return UA_FALSE;}

static UA_Boolean
allowDeleteNode(UA_Server *server, UA_AccessControl *ac,
                const UA_NodeId *sessionId, void *sessionContext,
                const UA_DeleteNodesItem *item) {return UA_FALSE;} // Do not allow deletion from client

static UA_Boolean
allowDeleteReference(UA_Server *server, UA_AccessControl *ac,
                     const UA_NodeId *sessionId, void *sessionContext,
                     const UA_DeleteReferencesItem *item) {return UA_FALSE;}

void* server_runner(void* arg)
{
	UA_StatusCode retval = UA_Server_run(server, &running);
    if(retval != UA_STATUSCODE_GOOD) {
        errx(EXIT_FAILURE, "Unexpected Server error %s", UA_StatusCode_name(retval));
    }
    return NULL;
}

static void
dataChangeNotificationCallback(UA_Server *server, UA_UInt32 monitoredItemId,
                               void *monitoredItemContext, const UA_NodeId *nodeId,
                               void *nodeContext, UA_UInt32 attributeId,
                               const UA_DataValue *value) {
}

void set_users_list_size(int size)
{
    users_list.list_size = size;
    users_list.username = (char **)calloc(size, sizeof(char *));
    users_list.password = (char **)calloc(size, sizeof(char *));
    users_list.logins = (UA_UsernamePasswordLogin *)calloc(size, sizeof(UA_UsernamePasswordLogin));  // v1.4.x
}

void delete_users_list()
{
    if(users_list.list_size == 0)
        return;

    for(size_t i = 0; i < users_list.list_size; i++) 
    {
        free(users_list.username[i]);
        free(users_list.password[i]);
        /* v1.4.x: Also clear the UA_STRING copies in logins */
        if(users_list.logins) {
            UA_String_clear(&users_list.logins[i].username);
            UA_String_clear(&users_list.logins[i].password);
        }
    }
    
    users_list.list_size = 0;
    free(users_list.username);
    free(users_list.password);
    free(users_list.logins);  // v1.4.x
    users_list.logins = NULL;
}

void delete_discovery_params()
{
    UA_ServerConfig *config = UA_Server_getConfig(server);

    if(config->applicationDescription.applicationUri.data)
        UA_String_clear(&config->applicationDescription.applicationUri);
    
    if(config->mdnsConfig.mdnsServerName.data)
        UA_String_clear(&config->mdnsConfig.mdnsServerName);

    if(discoveryClient)
        UA_Client_delete(discoveryClient);
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
*   Sets the server open62541 defaults configuration. 
*/
static void handle_set_default_server_config(void *entity, bool entity_type, const char *req, int *req_index)
{
    UA_ServerConfig_setDefault(UA_Server_getConfig(server));
    send_ok_response();
}

/* 
*   Creates a new server config with no network layer and no endpoints.
*/
static void handle_set_basics(void *entity, bool entity_type, const char *req, int *req_index)
{
    UA_ServerConfig_setBasics(UA_Server_getConfig(server));
    send_ok_response();
}

/* 
 *   Adds a TCP network layer with custom buffer sizes.
 */
static void handle_set_network_tcp_layer(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    long binary_len;

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_ATOM_EXT)
    {
        if (ei_decode_ulong(req, req_index, &port_number) < 0) {
            send_error_response("einval");
            return;
        }
    }
    else
    {
        char nil[4];
        if (ei_decode_atom(req, req_index, nil) < 0)
            errx(EXIT_FAILURE, "expecting command atom");
    }

    /* v1.4.x: Network layer is configured via setMinimal which includes TCP */
    UA_ServerConfig *config = UA_Server_getConfig(server);
    UA_StatusCode retval = UA_ServerConfig_setMinimal(config, (UA_UInt16) port_number, NULL);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }
    
    /* Enable password transmission without encryption for SecurityPolicy#None */
    config->allowNonePolicyPassword = true;

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

    /* v1.4.x: setCustomHostname removed, set via applicationDescription instead
     * TODO: Implement proper hostname setting in v1.4.x if needed
     */
    (void)host_name; /* Currently unused, reserved for future implementation */

    send_ok_response();
}

/* 
*   Sets the server port. 
*/
static void handle_set_port(void *entity, bool entity_type, const char *req, int *req_index)
{
    if (ei_decode_ulong(req, req_index, &port_number) < 0) {
        send_error_response("einval");
        return;
    }

    UA_ServerConfig *config = UA_Server_getConfig(server);
    UA_StatusCode retval = UA_ServerConfig_setMinimal(config, (UA_UInt16) port_number, NULL);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }
    
    /* Enable password transmission without encryption for SecurityPolicy#None */
    config->allowNonePolicyPassword = true;

    send_ok_response();
}

/* 
*   Configures users and passwords for authentication.
*   v1.4.x: Uses the successful pattern from server_access_control.c example
*   - Accepts a port parameter (default: 4840)
*   - For port 4840: uses default configuration from UA_Server_new()
*   - For other ports: calls setMinimal to configure the custom port
*   - Follows the pattern: allowNonePolicyPassword -> UA_AccessControl_default
*/
static void handle_set_users_and_passwords(void *entity, bool entity_type, const char *req, int *req_index)
{
    int list_arity;
    int tuple_arity;
    int term_type;
    int term_size;
    unsigned long port;

    /* Expect format: {[{user, pass}, ...], port} - Elixir handles the default */
    if(ei_decode_tuple_header(req, req_index, &tuple_arity) < 0 || tuple_arity != 2)
        errx(EXIT_FAILURE, ":handle_set_users_and_passwords requires a 2-tuple {users_list, port}, got arity = %d", tuple_arity);

    /* Decode the users list */
    if(ei_decode_list_header(req, req_index, &list_arity) < 0)
        errx(EXIT_FAILURE, ":handle_set_users_and_passwords users list required");

    /* Save the number of users before it gets overwritten */
    int num_users = list_arity;
    
    delete_users_list();
    set_users_list_size(num_users);

    /* Decode username/password pairs */
    for(size_t i = 0; i < num_users; i++) {
        if(ei_decode_tuple_header(req, req_index, &tuple_arity) < 0 || tuple_arity != 2)
            errx(EXIT_FAILURE, ":handle_set_users_and_passwords user entry requires a 2-tuple, term_size = %d", tuple_arity);

        if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
            errx(EXIT_FAILURE, "Invalid username (size)");

        users_list.username[i] = (char *)malloc(term_size + 1);
        long binary_len;
        if (ei_decode_binary(req, req_index, users_list.username[i], &binary_len) < 0) 
            errx(EXIT_FAILURE, "Invalid username");
        users_list.username[i][binary_len] = '\0';

        if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
            errx(EXIT_FAILURE, "Invalid password (size)");

        users_list.password[i] = (char *)malloc(term_size + 1);
        if (ei_decode_binary(req, req_index, users_list.password[i], &binary_len) < 0) 
            errx(EXIT_FAILURE, "Invalid password");
        users_list.password[i][binary_len] = '\0';

        /* Store logins in persistent structure using UA_STRING_ALLOC */
        users_list.logins[i].username = UA_STRING_ALLOC(users_list.username[i]);
        users_list.logins[i].password = UA_STRING_ALLOC(users_list.password[i]);
    }
    
    /* Decode the list terminator (empty list tail) */
    if(ei_decode_list_header(req, req_index, &list_arity) < 0 || list_arity != 0) {
        send_error_response("einval");
        return;
    }
    
    /* Decode the port */
    if (ei_decode_ulong(req, req_index, &port) < 0) {
        send_error_response("einval");
        return;
    }

    UA_ServerConfig *config = UA_Server_getConfig(server);
    
    /* v1.4.x: In v1.4.14, UA_Server_new() creates a server with 1 endpoint and 1 security policy
     * on port 4840 by default. Following the official example pattern:
     * - If port is 4840: use the default configuration from UA_Server_new()
     * - If port is NOT 4840: call setMinimal to configure the custom port
     */
    UA_StatusCode retval = UA_STATUSCODE_GOOD;
    if(port != 4840) {
        retval = UA_ServerConfig_setMinimal(config, (UA_UInt16)port, NULL);
        if(retval != UA_STATUSCODE_GOOD) {
            send_opex_response(retval);
            return;
        }
    }
    
    /* Enable password transmission without encryption for SecurityPolicy#None */
    config->allowNonePolicyPassword = true;
    
    /* Clear existing access control before reconfiguring */
    config->accessControl.clear(&config->accessControl);
    
    /* Configure authentication following the working example pattern */
    UA_Boolean allowAnonymous = true; /* Allow both anonymous AND username/password */
    UA_String encryptionPolicy = config->securityPolicies[config->securityPoliciesSize-1].policyUri;
    
    retval = UA_AccessControl_default(config, allowAnonymous, &encryptionPolicy, 
                                      num_users, users_list.logins);
    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }

    /* Restore custom access control callbacks */
    config->accessControl.allowAddNode = allowAddNode;
    config->accessControl.allowAddReference = allowAddReference;
    config->accessControl.allowDeleteNode = allowDeleteNode;
    config->accessControl.allowDeleteReference = allowDeleteReference;

    port_number = port;
    send_ok_response();
}

/* 
 *   Adds endpoints for all configured security policies in each mode.
 */
static void handle_add_all_endpoints(void *entity, bool entity_type, const char *req, int *req_index)
{
    UA_ServerConfig *config = UA_Server_getConfig(server);
    UA_StatusCode retval = UA_ServerConfig_addAllEndpoints(config);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }    

    send_ok_response();
}

static void handle_start_server(void *entity, bool entity_type, const char *req, int *req_index)
{
    running = true;
    pthread_create(&server_tid, NULL, server_runner, NULL);
    send_ok_response();
}

static void handle_stop_server(void *entity, bool entity_type, const char *req, int *req_index)
{
    running = false;
    send_ok_response();
}

/**************/
/* Encryption */
/**************/

/* 
 *   Creates a server configuration with all security policies for the given certificates.
 */
static void handle_set_config_with_security_policies(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    char *arg1;
    char *arg2;
    long binary_len;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 || term_size != 3)
        errx(EXIT_FAILURE, ":handle_set_config_with_security_policies requires a 3-tuple, term_size = %d", term_size);

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_ATOM_EXT)
    {
        if (ei_decode_ulong(req, req_index, &port_number) < 0) {
            send_error_response("einval");
            return;
        }
    }
    else
    {
        char nil[4];
        if (ei_decode_atom(req, req_index, nil) < 0)
            errx(EXIT_FAILURE, "expecting command atom");
    }

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid certificate (size)");

    arg1 = (char *)malloc(term_size + 1);

    if (ei_decode_binary(req, req_index, arg1, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid certificate");

    arg1[binary_len] = '\0';

    UA_ByteString certificate;
    certificate.data = arg1;
    certificate.length = binary_len;

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid private_key (size)");

    arg2 = (char *)malloc(term_size + 1);

    if (ei_decode_binary(req, req_index, arg2, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid private_key");

    arg2[binary_len] = '\0';

    UA_ByteString private_key;
    private_key.data = arg2;
    private_key.length = binary_len;

    /* Load the trustlist */
    size_t trust_list_size = 0;
    UA_ByteString *trust_list = NULL;

    /* Loading of a issuer list, not used in this application */
    size_t issuer_list_size = 0;
    UA_ByteString *issuer_list = NULL;

    /* Loading of a revocation list currently unsupported */
    size_t revocation_list_size = 0;
    UA_ByteString *revocation_list = NULL;

    UA_ServerConfig *config = UA_Server_getConfig(server);

    UA_StatusCode retval =
        UA_ServerConfig_setDefaultWithSecurityPolicies(config, (UA_Int16) port_number,
                                                       &certificate, &private_key,
                                                       trust_list, trust_list_size,
                                                       issuer_list, issuer_list_size,
                                                       revocation_list, revocation_list_size);

    /* v1.4.x: For testing, accept all certificates */
    if(retval == UA_STATUSCODE_GOOD) {
        UA_CertificateVerification_AcceptAll(&config->sessionPKI);
        UA_CertificateVerification_AcceptAll(&config->secureChannelPKI);
    }

    UA_ByteString_clear(&certificate);
    UA_ByteString_clear(&private_key);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }    

    send_ok_response();
}

/* 
 *   Adds the security policy ``SecurityPolicy#None`` to the server with certs.
 */
static void handle_add_security_policy_none(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    char *arg1;
    long binary_len;
    

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid certificate (size)");

    arg1 = (char *)malloc(term_size + 1);

    if (ei_decode_binary(req, req_index, arg1, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid certificate");

    arg1[binary_len] = '\0';

    UA_ByteString certificate;
    certificate.data = arg1;
    certificate.length = binary_len;

    UA_ServerConfig *config = UA_Server_getConfig(server);

    UA_StatusCode retval =
        UA_ServerConfig_addSecurityPolicyNone(config, &certificate);

    UA_ByteString_clear(&certificate);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }    

    send_ok_response();
}

/* 
 *   Adds the security policy ``SecurityPolicy#Basic128Rsa15`` to the server with certicate.
 */
static void handle_add_security_policy_basic128rsa15(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    char *arg1;
    char *arg2;
    long binary_len;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 || term_size != 2)
        errx(EXIT_FAILURE, ":handle_add_security_policy_basic128rsa15 requires a 2-tuple, term_size = %d", term_size);

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid certificate (size)");

    arg1 = (char *)malloc(term_size + 1);

    if (ei_decode_binary(req, req_index, arg1, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid certificate");

    arg1[binary_len] = '\0';

    UA_ByteString certificate;
    certificate.data = arg1;
    certificate.length = binary_len;

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid private_key (size)");

    arg2 = (char *)malloc(term_size + 1);

    if (ei_decode_binary(req, req_index, arg2, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid private_key");

    arg2[binary_len] = '\0';

    UA_ByteString private_key;
    private_key.data = arg2;
    private_key.length = binary_len;

    UA_ServerConfig *config = UA_Server_getConfig(server);

    UA_StatusCode retval =
        UA_ServerConfig_addSecurityPolicyBasic128Rsa15(config, &certificate, &private_key);

    UA_ByteString_clear(&certificate);
    UA_ByteString_clear(&private_key);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }    

    send_ok_response();
}

/* 
 *   Adds the security policy ``SecurityPolicy#Basic256`` to the server with certicate.
 */
static void handle_add_security_policy_basic256(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    char *arg1;
    char *arg2;
    long binary_len;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 || term_size != 2)
        errx(EXIT_FAILURE, ":handle_add_security_policy_basic256 requires a 2-tuple, term_size = %d", term_size);

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid certificate (size)");

    arg1 = (char *)malloc(term_size + 1);

    if (ei_decode_binary(req, req_index, arg1, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid certificate");

    arg1[binary_len] = '\0';

    UA_ByteString certificate;
    certificate.data = arg1;
    certificate.length = binary_len;

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid private_key (size)");

    arg2 = (char *)malloc(term_size + 1);

    if (ei_decode_binary(req, req_index, arg2, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid private_key");

    arg2[binary_len] = '\0';

    UA_ByteString private_key;
    private_key.data = arg2;
    private_key.length = binary_len;

    UA_ServerConfig *config = UA_Server_getConfig(server);

    UA_StatusCode retval =
        UA_ServerConfig_addSecurityPolicyBasic256(config, &certificate, &private_key);

    UA_ByteString_clear(&certificate);
    UA_ByteString_clear(&private_key);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }    

    send_ok_response();
}

/* 
 *   Adds the security policy ``SecurityPolicy#Basic256Sha256`` to the server with certicate.
 */
static void handle_add_security_policy_basic256sha256(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    char *arg1;
    char *arg2;
    long binary_len;
    
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 || term_size != 2)
        errx(EXIT_FAILURE, ":handle_add_security_policy_basic256sha256 requires a 2-tuple, term_size = %d", term_size);

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid certificate (size)");

    arg1 = (char *)malloc(term_size + 1);

    if (ei_decode_binary(req, req_index, arg1, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid certificate");

    arg1[binary_len] = '\0';

    UA_ByteString certificate;
    certificate.data = arg1;
    certificate.length = binary_len;

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid private_key (size)");

    arg2 = (char *)malloc(term_size + 1);

    if (ei_decode_binary(req, req_index, arg2, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid private_key");

    arg2[binary_len] = '\0';

    UA_ByteString private_key;
    private_key.data = arg2;
    private_key.length = binary_len;

    UA_ServerConfig *config = UA_Server_getConfig(server);

    UA_StatusCode retval =
        UA_ServerConfig_addSecurityPolicyBasic256Sha256(config, &certificate, &private_key);

    UA_ByteString_clear(&certificate);
    UA_ByteString_clear(&private_key);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }    

    send_ok_response();
}

/* 
 *   Adds all supported security policies and sets up certificate validation procedures.
 */
static void handle_add_all_security_policies(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    char *arg1;
    char *arg2;
    long binary_len;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 || term_size != 2)
        errx(EXIT_FAILURE, ":handle_add_all_security_policies requires a 2-tuple, term_size = %d", term_size);
    
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid certificate (size)");

    arg1 = (char *)malloc(term_size + 1);

    if (ei_decode_binary(req, req_index, arg1, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid certificate");

    arg1[binary_len] = '\0';

    UA_ByteString certificate;
    certificate.data = arg1;
    certificate.length = binary_len;

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
        errx(EXIT_FAILURE, "Invalid private_key (size)");

    arg2 = (char *)malloc(term_size + 1);

    if (ei_decode_binary(req, req_index, arg2, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid private_key");

    arg2[binary_len] = '\0';

    UA_ByteString private_key;
    private_key.data = arg2;
    private_key.length = binary_len;

    UA_ServerConfig *config = UA_Server_getConfig(server);

    UA_StatusCode retval =
        UA_ServerConfig_addAllSecurityPolicies(config, &certificate, &private_key);

    UA_ByteString_clear(&certificate);
    UA_ByteString_clear(&private_key);

    if(retval != UA_STATUSCODE_GOOD) {
        send_opex_response(retval);
        return;
    }    

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

    UA_UInt16 ns_id = UA_Server_addNamespace(server, namespace);
    uint32_t ns_id_32 = (uint32_t)ns_id;

    send_data_response(&ns_id_32, 2, 0);
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

/*************/
/* Discovery */
/*************/

/* 
 *  Sets the configuration for the a Server representing a local discovery server as a central instance.
 *  Any other server can register with this server using "discovery_register" function
 *  NOTE: before calling this function, this server should have the default configuration.
 *  LDS Servers only supports the Discovery Services. Cannot be used in combination with any other capability.
 */
void handle_set_lds_config(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_set_lds_config requires a 2-tuple, term_size = %d", term_size);

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
            errx(EXIT_FAILURE, "Invalid application_uri (type)");

    UA_String application_uri;
    application_uri.data = (char *)malloc(term_size + 1);
    application_uri.length = term_size;
    long binary_len;
    if (ei_decode_binary(req, req_index, application_uri.data, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid application_uri");
    application_uri.data[binary_len] = '\0';

    UA_ServerConfig *config = UA_Server_getConfig(server);

    // This is an LDS server only. Set the application type to DISCOVERYSERVER.
    config->applicationDescription.applicationType = UA_APPLICATIONTYPE_DISCOVERYSERVER;
    
    if(config->applicationDescription.applicationUri.data)
        UA_String_clear(&config->applicationDescription.applicationUri);
    
    config->applicationDescription.applicationUri = application_uri;

    // corrupted size vs. prev_size
    config->mdnsConfig.serverCapabilitiesSize = 1;
    UA_String *caps = (UA_String *) UA_Array_new(1, &UA_TYPES[UA_TYPES_STRING]);
    caps[0] = UA_String_fromChars("LDS");
    config->mdnsConfig.serverCapabilities = caps;

    // Enable the mDNS announce and response functionality
    config->mdnsEnabled = true;
    config->mdnsConfig.mdnsServerName = UA_String_fromChars("LDS");

    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_ATOM_EXT)
    {
        long timeout;
        if (ei_decode_ulong(req, req_index, &timeout) < 0) {
            send_error_response("einval");
            return;
        }
        // TODO: v1.4.x - find equivalent for cleanupTimeout if still available
        // config->discovery.cleanupTimeout = timeout;
    }
    else
    {
        char nil[4];
        if (ei_decode_atom(req, req_index, nil) < 0)
        errx(EXIT_FAILURE, "expecting command atom");
        // TODO: v1.4.x - find equivalent for cleanupTimeout if still available  
        // config->discovery.cleanupTimeout = 60*60;
    }

    send_ok_response();
}

/* 
 *  Registers a server in a discovery server.
 *  NOTE: before calling this function, this server should have the default 
 *  configuration and a port = 0.
 */
void handle_discovery_register(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    long binary_len;
    UA_StatusCode retval;

    UA_ServerConfig *config = UA_Server_getConfig(server);

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 4)
        errx(EXIT_FAILURE, ":handle_discovery_register requires a 4-tuple, term_size = %d", term_size);

    // application_uri
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
            errx(EXIT_FAILURE, "Invalid application_uri (type)");

    UA_String application_uri;
    application_uri.data = (char *)malloc(term_size + 1);
    application_uri.length = term_size;
    if (ei_decode_binary(req, req_index, application_uri.data, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid application_uri");
    application_uri.data[binary_len] = '\0';

    if(config->applicationDescription.applicationUri.data)
        UA_String_clear(&config->applicationDescription.applicationUri);
    
    config->applicationDescription.applicationUri = application_uri;

    // server_name
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
            errx(EXIT_FAILURE, "Invalid server_name (type)");

    UA_String server_name;
    server_name.data = (char *)malloc(term_size + 1);
    server_name.length = term_size;
    if (ei_decode_binary(req, req_index, server_name.data, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid server_name");
    server_name.data[binary_len] = '\0';

    if(config->mdnsConfig.mdnsServerName.data)
        UA_String_clear(&config->mdnsConfig.mdnsServerName);
    
    config->mdnsConfig.mdnsServerName = server_name;

    // endpoint
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_BINARY_EXT)
            errx(EXIT_FAILURE, "Invalid endpoint (type)");

    //char *endpoint = (char *)malloc(term_size + 1);
    char endpoint[term_size + 1];
    if (ei_decode_binary(req, req_index, endpoint, &binary_len) < 0) 
        errx(EXIT_FAILURE, "Invalid endpoint");
    endpoint[binary_len] = '\0';

    // timeout
    long timeout;
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 || term_type != ERL_ATOM_EXT)
    {
        if (ei_decode_ulong(req, req_index, &timeout) < 0) {
            send_error_response("einval");
            return;
        }
    }
    else
    {
        char nil[4];
        if (ei_decode_atom(req, req_index, nil) < 0)
            errx(EXIT_FAILURE, "expecting command atom");
        timeout = 10 * 60 * 1000;
    }

    if(discoveryClient != NULL)
        UA_Client_delete(discoveryClient);

    discoveryClient = UA_Client_new();
    UA_ClientConfig_setDefault(UA_Client_getConfig(discoveryClient));

    // v1.4.x: Use UA_Server_addRepeatedCallback for periodic discovery registration
    // Create a callback wrapper since the signature changed
    UA_UInt64 callbackId;
    retval = UA_Server_addRepeatedCallback(server, 
                                           (UA_ServerCallback)UA_Server_registerDiscovery, 
                                           discoveryClient, 
                                           (UA_Double)timeout, 
                                           &callbackId);
    
    if(retval != UA_STATUSCODE_GOOD) {
        UA_Client_disconnect(discoveryClient);
        UA_Client_delete(discoveryClient);
        send_opex_response(retval);
        return;
    }

    send_ok_response();
}

/* 
 *  Unregister the server from the discovery server.
 */
void handle_discovery_unregister(void *entity, bool entity_type, const char *req, int *req_index)
{
    // Note: v1.4.x API change - UA_Server_deregisterDiscovery requires UA_ClientConfig
    // TODO: Implement proper deregistration with UA_ClientConfig
    // UA_ClientConfig cc;
    // memset(&cc, 0, sizeof(UA_ClientConfig));
    // UA_ClientConfig_setDefault(&cc);
    // UA_String discoveryUrl = UA_STRING("opc.tcp://localhost:4840");
    // UA_StatusCode retval = UA_Server_deregisterDiscovery(server, &cc, discoveryUrl);
    // UA_ClientConfig_clear(&cc);
    
    UA_Client_disconnect(discoveryClient);
    //UA_Client_delete(discoveryClient);

    // For now, return success since old API is not available
    send_ok_response();
}

/************************/
/* Local MonitoredItems */
/************************/

/* 
 *  MonitoredItems are used with the Subscription mechanism of OPC UA to transported notifications for data changes and events. 
 *  MonitoredItems can also be registered locally. Notifications are then forwarded to a user-defined callback 
 *  instead of a remote client.
 */
void handle_add_monitored_item(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;
    UA_MonitoredItemCreateResult retval;

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":handle_add_monitored_item requires a 2-tuple, term_size = %d", term_size);

    UA_NodeId monitored_node = assemble_node_id(req, req_index);

    double sampling_interval;
    if (ei_decode_double(req, req_index, &sampling_interval) < 0) {
        send_error_response("einval");
        return;
    }

    UA_MonitoredItemCreateRequest monitor_request = UA_MonitoredItemCreateRequest_default(monitored_node);
    monitor_request.requestedParameters.samplingInterval = (UA_Double) sampling_interval;
    
    retval = UA_Server_createDataChangeMonitoredItem(server, UA_TIMESTAMPSTORETURN_SOURCE,
                                            monitor_request, NULL, dataChangeNotificationCallback);
    
    UA_NodeId_clear(&monitored_node);

    if(retval.statusCode != UA_STATUSCODE_GOOD) {
        send_opex_response(retval.statusCode);
        return;
    }

    send_data_response(&(retval.monitoredItemId), 27, 0);
}

void handle_delete_monitored_item(void *entity, bool entity_type, const char *req, int *req_index)
{
    int term_size;
    int term_type;

    unsigned long monitored_item_id;
    if (ei_decode_ulong(req, req_index, &monitored_item_id) < 0) {
        send_error_response("einval");
        return;
    }
    
    UA_StatusCode retval = UA_Server_deleteMonitoredItem(server, (UA_UInt32) monitored_item_id);

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
    {"read_node_value", handle_read_node_value},
    {"read_node_value_by_index", handle_read_node_value_by_index},
    {"write_node_display_name", handle_write_node_display_name},
    {"write_node_description", handle_write_node_description},
    {"write_node_write_mask", handle_write_node_write_mask},
    {"write_node_is_abstract", handle_write_node_is_abstract},
    {"write_node_inverse_name", handle_write_node_inverse_name},
    {"write_node_data_type", handle_write_node_data_type},
    {"write_node_value_rank", handle_write_node_value_rank},
    {"write_node_array_dimensions", handle_write_node_array_dimensions},
    {"write_node_access_level", handle_write_node_access_level},
    {"write_node_minimum_sampling_interval", handle_write_node_minimum_sampling_interval},
    {"write_node_historizing", handle_write_node_historizing},
    {"write_node_executable", handle_write_node_executable},
    {"write_node_blank_array", handle_write_node_blank_array},
    {"read_node_node_id", handle_read_node_node_id},
    {"read_node_node_class", handle_read_node_node_class},
    {"read_node_browse_name", handle_read_node_browse_name},
    {"read_node_display_name", handle_read_node_display_name},
    {"read_node_description", handle_read_node_description},
    {"read_node_write_mask", handle_read_node_write_mask},
    {"read_node_is_abstract", handle_read_node_is_abstract},
    {"read_node_symmetric", handle_read_node_symmetric},
    {"read_node_inverse_name", handle_read_node_inverse_name},
    {"read_node_contains_no_loops", handle_read_node_contains_no_loops},
    {"read_node_data_type", handle_read_node_data_type},
    {"read_node_value_rank", handle_read_node_value_rank},
    {"read_node_array_dimensions", handle_read_node_array_dimensions},
    {"read_node_access_level", handle_read_node_access_level},
    {"read_node_minimum_sampling_interval", handle_read_node_minimum_sampling_interval},
    {"read_node_historizing", handle_read_node_historizing},
    {"read_node_executable", handle_read_node_executable},
    // Local MonitoredItems
    {"add_monitored_item", handle_add_monitored_item},
    {"delete_monitored_item", handle_delete_monitored_item},
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
    // configuration & lifecycle functions
    {"get_server_config", handle_get_server_config},
    {"set_default_server_config", handle_set_default_server_config},
    {"set_basics", handle_set_basics},
    {"set_network_tcp_layer", handle_set_network_tcp_layer},
    {"set_hostname", handle_set_hostname},
    {"set_port", handle_set_port},
    {"set_users", handle_set_users_and_passwords},
    {"add_all_endpoints", handle_add_all_endpoints},
    {"start_server", handle_start_server},
    {"stop_server", handle_stop_server},
    // Encryption
    {"set_config_with_security_policies", handle_set_config_with_security_policies},
    {"add_security_policy_none", handle_add_security_policy_none},
    {"add_security_policy_basic128rsa15", handle_add_security_policy_basic128rsa15},
    {"add_security_policy_basic256", handle_add_security_policy_basic256},
    {"add_security_policy_basic256sha256", handle_add_security_policy_basic256sha256},
    {"add_all_security_policies", handle_add_all_security_policies},
    // Discovery
    {"set_lds_config", handle_set_lds_config},
    {"discovery_register", handle_discovery_register},
    {"discovery_unregister", handle_discovery_unregister},
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
    // {atom(), {pid(), ref()}, term()}
    int req_index = sizeof(uint16_t);
    if (ei_decode_version(req, &req_index, NULL) < 0)
        errx(EXIT_FAILURE, "Message version issue?");

    int arity;
    if (ei_decode_tuple_header(req, &req_index, &arity) < 0 ||
            arity != 3)
        errx(EXIT_FAILURE, "expecting {cmd, {pid, ref}, args} tuple");

    char cmd[MAXATOMLEN];
    if (ei_decode_atom(req, &req_index, cmd) < 0)
        errx(EXIT_FAILURE, "expecting command atom");
    
    //execute all handler
    for (struct request_handler *rh = request_handlers; rh->name != NULL; rh++) {
        if (strcmp(cmd, rh->name) == 0) {
            handle_caller_metadata(req, &req_index, cmd);
            rh->handler(server, 0, req, &req_index);
            free_caller_metadata();
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
    delete_users_list();
    delete_discovery_params();
    // Release threads memory
    pthread_join(server_tid, NULL);
    UA_Server_delete(server); 
}