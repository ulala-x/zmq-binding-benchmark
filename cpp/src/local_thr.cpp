/*
 * ZeroMQ C++ Throughput Test - Local (Receiver)
 *
 * Receives messages using PULL socket and measures throughput.
 * Pattern: PULL -> PUSH (unidirectional data flow)
 *
 * Usage: ./local_thr <bind_to> <message_size> <message_count>
 * Example: ./local_thr tcp://*:5556 64 1000000
 */

#include <zmq.hpp>
#include <iostream>
#include <chrono>
#include <cstring>

int main(int argc, char *argv[]) {
    if (argc != 4) {
        std::cerr << "Usage: " << argv[0] << " <bind_to> <message_size> <message_count>\n";
        std::cerr << "Example: " << argv[0] << " tcp://*:5556 64 1000000\n";
        return 1;
    }

    const char *bind_to = argv[1];
    size_t message_size = std::atoi(argv[2]);
    int message_count = std::atoi(argv[3]);

    if (message_size <= 0 || message_count <= 0) {
        std::cerr << "Error: message_size and message_count must be positive\n";
        return 1;
    }

    try {
        // Create context and PULL socket
        zmq::context_t context(1);
        zmq::socket_t socket(context, zmq::socket_type::pull);

        // Bind to endpoint
        socket.bind(bind_to);
        std::cout << "Listening on " << bind_to << "\n";
        std::cout << "Message size: " << message_size << " bytes\n";
        std::cout << "Message count: " << message_count << "\n";
        std::cout << "Waiting for messages...\n";

        // Receive first message (warm-up, start timing after first message)
        zmq::message_t first_msg;
        auto recv_result = socket.recv(first_msg, zmq::recv_flags::none);
        if (!recv_result) {
            std::cerr << "Error: Failed to receive first message\n";
            return 1;
        }

        if (first_msg.size() != message_size) {
            std::cerr << "Error: Message size mismatch. Expected " << message_size
                      << ", got " << first_msg.size() << "\n";
            return 1;
        }

        std::cout << "First message received. Starting measurement...\n";

        // Start timing
        auto start = std::chrono::high_resolution_clock::now();

        // Receive remaining messages
        for (int i = 1; i < message_count; i++) {
            zmq::message_t message;
            recv_result = socket.recv(message, zmq::recv_flags::none);

            if (!recv_result) {
                std::cerr << "Error: Failed to receive message " << i << "\n";
                return 1;
            }

            // Verify message size
            if (message.size() != message_size) {
                std::cerr << "Error: Message size mismatch at message " << i
                          << ". Expected " << message_size << ", got " << message.size() << "\n";
                return 1;
            }

            // Progress indicator (every 10%)
            if (message_count > 100 && (i + 1) % (message_count / 10) == 0) {
                int progress = ((i + 1) * 100) / message_count;
                std::cout << "Progress: " << progress << "% (" << (i + 1) << "/" << message_count << ")\n";
            }
        }

        // Stop timing
        auto end = std::chrono::high_resolution_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();

        // Calculate throughput
        double elapsed_sec = static_cast<double>(elapsed) / 1000000.0;
        double throughput = static_cast<double>(message_count - 1) / elapsed_sec;
        double megabits = (throughput * message_size * 8) / 1000000.0;

        // Print results
        std::cout << "\n=== Throughput Test Results ===\n";
        std::cout << "Received: " << message_count << " messages\n";
        std::cout << "Message size: " << message_size << " bytes\n";
        std::cout << "Total data: " << (message_size * message_count / (1024.0 * 1024.0)) << " MB\n";
        std::cout << "Elapsed time: " << elapsed_sec << " seconds\n";
        std::cout << "Throughput: " << throughput << " msg/s\n";
        std::cout << "Throughput: " << megabits << " Mb/s\n";

    } catch (const zmq::error_t &e) {
        std::cerr << "ZMQ Error: " << e.what() << "\n";
        return 1;
    } catch (const std::exception &e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
