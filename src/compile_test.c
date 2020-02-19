#include <open62541.h>

#include <signal.h>
#include <stdlib.h>

static volatile UA_Boolean running = true;
static void stopHandler(int sig) {
    UA_LOG_INFO(UA_Log_Stdout, UA_LOGCATEGORY_USERLAND, "received ctrl-c");
    running = false;
}

int main(int argc, char *argv[]) {
    signal(SIGINT, stopHandler);
    signal(SIGTERM, stopHandler);

    UA_Server *server = UA_Server_new();
    UA_ServerConfig_setDefault(UA_Server_getConfig(server));

    //Check for arguments
    if(argc > 2)    //hostname or ip address and a port number are available
    {
        UA_Int16 port_number = atoi(argv[2]);
        UA_ServerConfig_setMinimal(UA_Server_getConfig(server), port_number, 0);
    }
    else
    {
        UA_ServerConfig_setDefault(UA_Server_getConfig(server));
    }
    
    if(argc > 1)
    {
        //hostname or ip address available
        //copy the hostname from char * to an open62541 variable
        UA_String hostname;
        UA_String_init(&hostname);
        hostname.length = strlen(argv[1]);
        hostname.data = (UA_Byte *) argv[1]; //da la dirección del apuntador de los argumentos.

        UA_ServerConfig_setCustomHostname(UA_Server_getConfig(server), hostname);
    }

    UA_StatusCode retval = UA_Server_run(server, &running);

    UA_Server_delete(server);
    return retval == UA_STATUSCODE_GOOD ? EXIT_SUCCESS : EXIT_FAILURE;
}
