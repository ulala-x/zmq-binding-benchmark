/*
 * ZeroMQ C++ Throughput Test - Remote (Sender)
 *
 * Sends messages using PUSH socket for throughput measurement.
 * Pattern: PUSH -> PULL (unidirectional data flow)
 *
 * Usage: ./remote_thr <connect_to> <message_size> <message_count>
 * Example: ./remote_thr tcp://localhost:5556 64 1000000
 */

#include <zmq.hpp>
#include <iostream>
#include <vector>
#include <cstring>
#include <thread>
#include <chrono>

int main(int argc, char *argv[]) {
    if (argc != 4) {
        std::cerr << "Usage: " << argv[0] << " <connect_to> <message_size> <message_count>\n";
        std::cerr << "Example: " << argv[0] << " tcp://localhost:5556 64 1000000\n";
        return 1;
    }

    const char *connect_to = argv[1];
    size_t message_size = std::atoi(argv[2]);
    int message_count = std::atoi(argv[3]);

    if (message_size <= 0 || message_count <= 0) {
        std::cerr << "Error: message_size and message_count must be positive\n";
        return 1;
    }

    try {
        // Create context and PUSH socket
        zmq::context_t context(1);
        zmq::socket_t socket(context, zmq::socket_type::push);

        // Connect to receiver
        socket.connect(connect_to);
        std::cout << "Connected to " << connect_to << "\n";
        std::cout << "Message size: " << message_size << " bytes\n";
        std::cout << "Message count: " << message_count << "\n";

        // Wait for connection to establish
        std::this_thread::sleep_for(std::chrono::milliseconds(100));

        // Prepare message buffer
        std::vector<char> buffer(message_size, 'X');

        std::cout << "Sending messages...\n";

        // Send messages
        for (int i = 0; i < message_count; i++) {
            zmq::message_t message(buffer.data(), message_size);
            auto result = socket.send(message, zmq::send_flags::none);

            if (!result) {
                std::cerr << "Error: Failed to send message " << i << "\n";
                return 1;
            }

            // Progress indicator (every 10%)
            if (message_count > 100 && (i + 1) % (message_count / 10) == 0) {
                int progress = ((i + 1) * 100) / message_count;
                std::cout << "Progress: " << progress << "% (" << (i + 1) << "/" << message_count << ")\n";
            }
        }

        std::cout << "\nSent " << message_count << " messages successfully.\n";
        std::cout << "Total data sent: " << (message_size * message_count / (1024.0 * 1024.0)) << " MB\n";

        // Give time for messages to be delivered
        std::this_thread::sleep_for(std::chrono::milliseconds(100));

    } catch (const zmq::error_t &e) {
        std::cerr << "ZMQ Error: " << e.what() << "\n";
        return 1;
    } catch (const std::exception &e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
