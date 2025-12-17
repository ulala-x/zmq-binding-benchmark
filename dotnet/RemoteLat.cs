/*
 * ZeroMQ .NET Latency Test - Remote (Client)
 *
 * Measures round-trip latency using REQ socket.
 * Pattern: REQ -> REP (synchronous request-reply)
 *
 * Usage: remote_lat <connect_to> <message_size> <roundtrip_count>
 * Example: remote_lat tcp://127.0.0.1:5555 64 10000
 */

using Net.Zmq;
using System.Diagnostics;

namespace NetZmq.PerfTests;

public static class RemoteLat
{
    public static int Run(string[] args)
    {
        if (args.Length != 3)
        {
            Console.Error.WriteLine("Usage: remote_lat <connect_to> <message_size> <roundtrip_count>");
            Console.Error.WriteLine("Example: remote_lat tcp://127.0.0.1:5555 64 10000");
            return 1;
        }

        string connectTo = args[0];
        if (!int.TryParse(args[1], out int messageSize) || messageSize <= 0)
        {
            Console.Error.WriteLine("Error: message_size must be a positive integer");
            return 1;
        }

        if (!int.TryParse(args[2], out int roundtripCount) || roundtripCount <= 0)
        {
            Console.Error.WriteLine("Error: roundtrip_count must be a positive integer");
            return 1;
        }

        try
        {
            // Create context and REQ socket
            using var context = new Context();
            using var socket = new Socket(context, SocketType.Req);

            // Connect to server
            socket.Connect(connectTo);
            Console.WriteLine($"Connected to {connectTo}");
            Console.WriteLine($"Message size: {messageSize} bytes");
            Console.WriteLine($"Roundtrip count: {roundtripCount}");

            // Prepare message buffer
            byte[] sendBuffer = new byte[messageSize];
            Array.Fill(sendBuffer, (byte)'X');

            byte[] recvBuffer = new byte[messageSize];

            // Warm-up
            socket.Send(sendBuffer);
            socket.Recv(recvBuffer);

            // Start timing
            var stopwatch = Stopwatch.StartNew();

            // Perform roundtrips
            for (int i = 0; i < roundtripCount; i++)
            {
                // Send request
                socket.Send(sendBuffer);

                // Receive reply
                int bytesReceived = socket.Recv(recvBuffer);

                // Verify message size
                if (bytesReceived != messageSize)
                {
                    Console.Error.WriteLine($"Error: Message size mismatch. Expected {messageSize}, got {bytesReceived}");
                    return 1;
                }
            }

            // Stop timing
            stopwatch.Stop();
            long elapsedMicroseconds = stopwatch.ElapsedTicks * 1_000_000 / Stopwatch.Frequency;

            // Calculate latency (divide by 2 for one-way, not round-trip)
            double latency = (double)elapsedMicroseconds / (roundtripCount * 2);
            double messageRate = roundtripCount * 1_000_000.0 / elapsedMicroseconds;

            // Print results
            Console.WriteLine();
            Console.WriteLine("=== Latency Test Results ===");
            Console.WriteLine($"Average latency: {latency:F4} us");
            Console.WriteLine($"Total elapsed time: {elapsedMicroseconds} us");
            Console.WriteLine($"Message rate: {messageRate:F2} msg/s");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error: {ex.Message}");
            return 1;
        }

        return 0;
    }
}
