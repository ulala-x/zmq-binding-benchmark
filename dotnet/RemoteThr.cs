/*
 * ZeroMQ .NET Throughput Test - Remote (Sender)
 *
 * Sends messages using PUSH socket for throughput measurement.
 * Pattern: PUSH -> PULL (unidirectional data flow)
 *
 * Usage: remote_thr <connect_to> <message_size> <message_count>
 * Example: remote_thr tcp://127.0.0.1:5556 64 1000000
 */

using Net.Zmq;

namespace NetZmq.PerfTests;

public static class RemoteThr
{
    public static int Run(string[] args)
    {
        if (args.Length != 3)
        {
            Console.Error.WriteLine("Usage: remote_thr <connect_to> <message_size> <message_count>");
            Console.Error.WriteLine("Example: remote_thr tcp://127.0.0.1:5556 64 1000000");
            return 1;
        }

        string connectTo = args[0];
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
            // Create context and PUSH socket
            using var context = new Context();
            using var socket = new Socket(context, SocketType.Push);

            // Connect to receiver
            socket.Connect(connectTo);
            Console.WriteLine($"Connected to {connectTo}");
            Console.WriteLine($"Message size: {messageSize} bytes");
            Console.WriteLine($"Message count: {messageCount}");

            // Wait for connection to establish
            Thread.Sleep(100);

            // Prepare message buffer
            byte[] buffer = new byte[messageSize];
            Array.Fill(buffer, (byte)'X');

            Console.WriteLine("Sending messages...");

            // Send messages
            for (int i = 0; i < messageCount; i++)
            {
                socket.Send(buffer);

                // Progress indicator (every 10%)
                if (messageCount > 100 && (i + 1) % (messageCount / 10) == 0)
                {
                    int progress = ((i + 1) * 100) / messageCount;
                    Console.WriteLine($"Progress: {progress}% ({i + 1}/{messageCount})");
                }
            }

            double totalDataMB = (messageSize * (long)messageCount) / (1024.0 * 1024.0);
            Console.WriteLine();
            Console.WriteLine($"Sent {messageCount} messages successfully.");
            Console.WriteLine($"Total data sent: {totalDataMB:F2} MB");

            // Give time for messages to be delivered
            Thread.Sleep(100);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error: {ex.Message}");
            return 1;
        }

        return 0;
    }
}
