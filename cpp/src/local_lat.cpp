/*
 * ZeroMQ C++ Latency Test - Local (Server)
 *
 * Echo server using REP socket.
 * Pattern: REP -> REQ (synchronous request-reply)
 *
 * Usage: ./local_lat <bind_to> <message_size> <roundtrip_count>
 * Example: ./local_lat tcp://*:5555 64 10000
 */

#include <zmq.hpp>
#include <iostream>
#include <cstring>

int main(int argc, char *argv[]) {
    if (argc != 4) {
        std::cerr << "Usage: " << argv[0] << " <bind_to> <message_size> <roundtrip_count>\n";
        std::cerr << "Example: " << argv[0] << " tcp://*:5555 64 10000\n";
        return 1;
    }

    const char *bind_to = argv[1];
    size_t message_size = std::atoi(argv[2]);
    int roundtrip_count = std::atoi(argv[3]);

    if (message_size <= 0 || roundtrip_count <= 0) {
        std::cerr << "Error: message_size and roundtrip_count must be positive\n";
        return 1;
    }

    try {
        // Create context and REP socket
        zmq::context_t context(1);
        zmq::socket_t socket(context, zmq::socket_type::rep);

        // Bind to endpoint
        socket.bind(bind_to);
        std::cout << "Listening on " << bind_to << "\n";
        std::cout << "Message size: " << message_size << " bytes\n";
        std::cout << "Roundtrip count: " << roundtrip_count << "\n";
        std::cout << "Waiting for messages...\n";

        // Warm-up
        zmq::message_t warmup;
        socket.recv(warmup, zmq::recv_flags::none);
        socket.send(warmup, zmq::send_flags::none);

        // Echo loop - receive and send back (roundtrip_count times)
        for (int i = 0; i < roundtrip_count; i++) {
            // Receive message
            zmq::message_t request;
            auto recv_result = socket.recv(request, zmq::recv_flags::none);
            if (!recv_result) {
                std::cerr << "Error: Failed to receive message " << i << "\n";
                return 1;
            }

            // Verify message size
            if (request.size() != message_size) {
                std::cerr << "Error: Message size mismatch. Expected " << message_size
                          << ", got " << request.size() << "\n";
                return 1;
            }

            // Echo back (send the same message)
            auto send_result = socket.send(request, zmq::send_flags::none);
            if (!send_result) {
                std::cerr << "Error: Failed to send message " << i << "\n";
                return 1;
            }
        }

        std::cout << "\nCompleted " << roundtrip_count << " roundtrips.\n";

    } catch (const zmq::error_t &e) {
        std::cerr << "ZMQ Error: " << e.what() << "\n";
        return 1;
    } catch (const std::exception &e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
