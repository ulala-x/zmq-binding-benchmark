/*
 * ZeroMQ .NET Latency Test - Local (Server)
 *
 * Echo server using REP socket.
 * Pattern: REP -> REQ (synchronous request-reply)
 *
 * Usage: local_lat <bind_to> <message_size> <roundtrip_count>
 * Example: local_lat tcp://*:5555 64 10000
 */

using Net.Zmq;

namespace NetZmq.PerfTests;

public static class LocalLat
{
    public static int Run(string[] args)
    {
        if (args.Length != 3)
        {
            Console.Error.WriteLine("Usage: local_lat <bind_to> <message_size> <roundtrip_count>");
            Console.Error.WriteLine("Example: local_lat tcp://*:5555 64 10000");
            return 1;
        }

        string bindTo = args[0];
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
            // Create context and REP socket
            using var context = new Context();
            using var socket = new Socket(context, SocketType.Rep);

            // Bind to endpoint
            socket.Bind(bindTo);
            Console.WriteLine($"Listening on {bindTo}");
            Console.WriteLine($"Message size: {messageSize} bytes");
            Console.WriteLine($"Roundtrip count: {roundtripCount}");
            Console.WriteLine("Waiting for messages...");

            // Prepare receive buffer
            byte[] buffer = new byte[messageSize];

            // Warm-up
            int warmupBytes = socket.Recv(buffer);
            socket.Send(buffer);

            // Echo loop - receive and send back (roundtrip_count times)
            for (int i = 0; i < roundtripCount; i++)
            {
                // Receive message
                int bytesReceived = socket.Recv(buffer);

                // Verify message size
                if (bytesReceived != messageSize)
                {
                    Console.Error.WriteLine($"Error: Message size mismatch. Expected {messageSize}, got {bytesReceived}");
                    return 1;
                }

                // Echo back (send the same message)
                socket.Send(buffer);
            }

            Console.WriteLine($"\nCompleted {roundtripCount} roundtrips.");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error: {ex.Message}");
            return 1;
        }

        return 0;
    }
}
