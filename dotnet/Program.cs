/*
 * ZeroMQ .NET Performance Test Suite
 *
 * Entry point for routing to different test types.
 *
 * Usage:
 *   dotnet run -c Release -- local_lat <bind_to> <message_size> <roundtrip_count>
 *   dotnet run -c Release -- remote_lat <connect_to> <message_size> <roundtrip_count>
 *   dotnet run -c Release -- local_thr <bind_to> <message_size> <message_count>
 *   dotnet run -c Release -- remote_thr <connect_to> <message_size> <message_count>
 */

namespace NetZmq.PerfTests;

class Program
{
    static int Main(string[] args)
    {
        if (args.Length < 1)
        {
            Console.Error.WriteLine("Usage: <test_type> <args...>");
            Console.Error.WriteLine();
            Console.Error.WriteLine("Test types:");
            Console.Error.WriteLine("  local_lat <bind_to> <message_size> <roundtrip_count>");
            Console.Error.WriteLine("  remote_lat <connect_to> <message_size> <roundtrip_count>");
            Console.Error.WriteLine("  local_thr <bind_to> <message_size> <message_count>");
            Console.Error.WriteLine("  remote_thr <connect_to> <message_size> <message_count>");
            Console.Error.WriteLine();
            Console.Error.WriteLine("Examples:");
            Console.Error.WriteLine("  dotnet run -c Release -- local_lat tcp://*:5555 64 10000");
            Console.Error.WriteLine("  dotnet run -c Release -- remote_lat tcp://127.0.0.1:5555 64 10000");
            Console.Error.WriteLine("  dotnet run -c Release -- local_thr tcp://*:5556 64 1000000");
            Console.Error.WriteLine("  dotnet run -c Release -- remote_thr tcp://127.0.0.1:5556 64 1000000");
            return 1;
        }

        string testType = args[0].ToLower();
        string[] testArgs = args.Skip(1).ToArray();

        try
        {
            return testType switch
            {
                "local_lat" => LocalLat.Run(testArgs),
                "remote_lat" => RemoteLat.Run(testArgs),
                "local_thr" => LocalThr.Run(testArgs),
                "remote_thr" => RemoteThr.Run(testArgs),
                _ => throw new ArgumentException($"Unknown test type: {testType}")
            };
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error: {ex.Message}");
            return 1;
        }
    }
}
