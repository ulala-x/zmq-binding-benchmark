/*
 * ZeroMQ C++ Latency Test - Remote (Client)
 *
 * Measures round-trip latency using REQ socket.
 * Pattern: REQ -> REP (synchronous request-reply)
 *
 * Usage: ./remote_lat <connect_to> <message_size> <roundtrip_count>
 * Example: ./remote_lat tcp://localhost:5555 64 10000
 */

#include <zmq.hpp>
#include <iostream>
#include <chrono>
#include <cstring>

int main(int argc, char *argv[]) {
    if (argc != 4) {
        std::cerr << "Usage: " << argv[0] << " <connect_to> <message_size> <roundtrip_count>\n";
        std::cerr << "Example: " << argv[0] << " tcp://localhost:5555 64 10000\n";
        return 1;
    }

    const char *connect_to = argv[1];
    size_t message_size = std::atoi(argv[2]);
    int roundtrip_count = std::atoi(argv[3]);

    if (message_size <= 0 || roundtrip_count <= 0) {
        std::cerr << "Error: message_size and roundtrip_count must be positive\n";
        return 1;
    }

    try {
        // Create context and REQ socket
        zmq::context_t context(1);
        zmq::socket_t socket(context, zmq::socket_type::req);

        // Connect to server
        socket.connect(connect_to);
        std::cout << "Connected to " << connect_to << "\n";
        std::cout << "Message size: " << message_size << " bytes\n";
        std::cout << "Roundtrip count: " << roundtrip_count << "\n";

        // Prepare message buffer
        std::vector<char> send_buf(message_size, 'X');
        std::vector<char> recv_buf(message_size);

        // Warm-up
        zmq::message_t warmup_send(send_buf.data(), message_size);
        socket.send(warmup_send, zmq::send_flags::none);

        zmq::message_t warmup_recv;
        socket.recv(warmup_recv, zmq::recv_flags::none);

        // Start timing
        auto start = std::chrono::high_resolution_clock::now();

        // Perform roundtrips
        for (int i = 0; i < roundtrip_count; i++) {
            // Send request
            zmq::message_t request(send_buf.data(), message_size);
            auto send_result = socket.send(request, zmq::send_flags::none);
            if (!send_result) {
                std::cerr << "Error: Failed to send message " << i << "\n";
                return 1;
            }

            // Receive reply
            zmq::message_t reply;
            auto recv_result = socket.recv(reply, zmq::recv_flags::none);
            if (!recv_result) {
                std::cerr << "Error: Failed to receive message " << i << "\n";
                return 1;
            }

            // Verify message size
            if (reply.size() != message_size) {
                std::cerr << "Error: Message size mismatch. Expected " << message_size
                          << ", got " << reply.size() << "\n";
                return 1;
            }
        }

        // Stop timing
        auto end = std::chrono::high_resolution_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();

        // Calculate latency (divide by 2 for one-way, not round-trip)
        double latency = static_cast<double>(elapsed) / static_cast<double>(roundtrip_count * 2);

        // Print results
        std::cout << "\n=== Latency Test Results ===\n";
        std::cout << "Average latency: " << latency << " us\n";
        std::cout << "Total elapsed time: " << elapsed << " us\n";
        std::cout << "Message rate: " << (roundtrip_count * 1000000.0 / elapsed) << " msg/s\n";

    } catch (const zmq::error_t &e) {
        std::cerr << "ZMQ Error: " << e.what() << "\n";
        return 1;
    } catch (const std::exception &e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
