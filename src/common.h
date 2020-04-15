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

#ifndef UTIL_H
#define UTIL_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "open62541.h"

//#define DEBUG

#ifdef DEBUG
FILE *log_location;
#define LOG_LOCATION log_location
#define debug(...) do { fprintf(log_location, __VA_ARGS__); fprintf(log_location, "\r\n"); fflush(log_location); } while(0)
#else
#define LOG_LOCATION stderr
#define debug(...)
#endif

#ifndef __WIN32__
#include <err.h>
#else
// If err.h doesn't exist, define substitutes.
#define err(STATUS, MSG, ...) do { fprintf(LOG_LOCATION, "nerves_uart: " MSG "\n", ## __VA_ARGS__); fflush(LOG_LOCATION); exit(STATUS); } while (0)
#define errx(STATUS, MSG, ...) do { fprintf(LOG_LOCATION, "nerves_uart: " MSG "\n", ## __VA_ARGS__); fflush(LOG_LOCATION); exit(STATUS); } while (0)
#define warn(MSG, ...) do { fprintf(LOG_LOCATION, "nerves_uart: " MSG "\n", ## __VA_ARGS__); fflush(LOG_LOCATION); } while (0)
#define warnx(MSG, ...) do { fprintf(LOG_LOCATION, "nerves_uart: " MSG "\n", ## __VA_ARGS__); fflush(LOG_LOCATION); } while (0)
#endif

#define ONE_YEAR_MILLIS (1000ULL * 60 * 60 * 24 * 365)
uint64_t current_time();

#endif // UTIL_H

//Client and Server common functions
UA_NodeId assemble_node_id(const char *req, int *req_index);
UA_ExpandedNodeId assemble_expanded_node_id(const char *req, int *req_index);
UA_QualifiedName assemble_qualified_name(const char *req, int *req_index);

// Elixir Message assemblers
void encode_client_config(char *resp, int *resp_index, void *data);
void encode_server_on_the_network_struct(char *resp, int *resp_index, void *data, int data_len);
void encode_application_description_struct(char *resp, int *resp_index, void *data, int data_len);
void encode_endpoint_description_struct(char *resp, int *resp_index, void *data, int data_len);
void encode_server_config(char *resp, int *resp_index, void *data);
void send_data_response(void *data, int data_type, int data_len);
void send_error_response(const char *reason);
void send_ok_response();
void send_opex_response(uint32_t reason);

//Client and Server common handlers
void handle_test(void *data, int data_type, int data_len);
