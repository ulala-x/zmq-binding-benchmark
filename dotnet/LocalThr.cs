/*
 * ZeroMQ .NET Throughput Test - Local (Receiver)
 *
 * Receives messages using PULL socket and measures throughput.
 * Pattern: PULL -> PUSH (unidirectional data flow)
 *
 * Usage: local_thr <bind_to> <message_size> <message_count>
 * Example: local_thr tcp://*:5556 64 1000000
 */

using Net.Zmq;
using System.Diagnostics;

namespace NetZmq.PerfTests;

public static class LocalThr
{
    public static int Run(string[] args)
    {
        if (args.Length != 3)
        {
            Console.Error.WriteLine("Usage: local_thr <bind_to> <message_size> <message_count>");
            Console.Error.WriteLine("Example: local_thr tcp://*:5556 64 1000000");
            return 1;
        }

        string bindTo = args[0];
        if (!int.TryParse(args[1], out int messageSize) || messageSize <= 0)
        {
            Console.Error.WriteLine("Error: message_size must be a positive integer");
            return 1;
        }

        if (!int.TryParse(args[2], out int messageCount) || messageCount <= 0)
        {
            Console.Error.WriteLine("Error: message_count must be a positive integer");
            return 1;
        }

        try
        {
            // Create context and PULL socket
            using var context = new Context();
            using var socket = new Socket(context, SocketType.Pull);

            // Bind to endpoint
            socket.Bind(bindTo);
            Console.WriteLine($"Listening on {bindTo}");
            Console.WriteLine($"Message size: {messageSize} bytes");
            Console.WriteLine($"Message count: {messageCount}");
            Console.WriteLine("Waiting for messages...");

            // Receive first message (warm-up, start timing after first message)
            using (var firstMsg = new Message())
            {
                socket.Recv(firstMsg, RecvFlags.None);

                if (firstMsg.Size != messageSize)
                {
                    Console.Error.WriteLine($"Error: Message size mismatch. Expected {messageSize}, got {firstMsg.Size}");
                    return 1;
                }
            }

            Console.WriteLine("First message received. Starting measurement...");

            // Start timing
            var stopwatch = Stopwatch.StartNew();

            // Receive remaining messages
            for (int i = 1; i < messageCount; i++)
            {
                using (var message = new Message())
                {
                    socket.Recv(message, RecvFlags.None);

                    // Verify message size
                    if (message.Size != messageSize)
                    {
                        Console.Error.WriteLine($"Error: Message size mismatch at message {i}. Expected {messageSize}, got {message.Size}");
                        return 1;
                    }
                }

                // Progress indicator (every 10%)
                if (messageCount > 100 && (i + 1) % (messageCount / 10) == 0)
                {
                    int progress = ((i + 1) * 100) / messageCount;
                    Console.WriteLine($"Progress: {progress}% ({i + 1}/{messageCount})");
                }
            }

            // Stop timing
            stopwatch.Stop();
            long elapsedMicroseconds = stopwatch.ElapsedTicks * 1_000_000 / Stopwatch.Frequency;

            // Calculate throughput
            double elapsedSeconds = elapsedMicroseconds / 1_000_000.0;
            double throughput = (messageCount - 1) / elapsedSeconds;
            double megabits = (throughput * messageSize * 8) / 1_000_000.0;
            double totalDataMB = (messageSize * (long)messageCount) / (1024.0 * 1024.0);

            // Print results
            Console.WriteLine();
            Console.WriteLine("=== Throughput Test Results ===");
            Console.WriteLine($"Received: {messageCount} messages");
            Console.WriteLine($"Message size: {messageSize} bytes");
            Console.WriteLine($"Total data: {totalDataMB:F2} MB");
            Console.WriteLine($"Elapsed time: {elapsedSeconds:F5} seconds");
            Console.WriteLine($"Throughput: {throughput:G6} msg/s");
            Console.WriteLine($"Throughput: {megabits:F1} Mb/s");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error: {ex.Message}");
            return 1;
        }

        return 0;
    }
}
