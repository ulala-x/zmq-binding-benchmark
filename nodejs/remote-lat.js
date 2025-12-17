#!/usr/bin/env node
/*
 * ZeroMQ Node.js Latency Test - Remote (Client)
 *
 * Measures round-trip latency using REQ socket.
 * Pattern: REQ -> REP (synchronous request-reply)
 *
 * Usage: node remote-lat.js <connect_to> <message_size> <roundtrip_count>
 * Example: node remote-lat.js tcp://127.0.0.1:5555 64 10000
 */

import zmq from 'zeromq';

async function main() {
  // Parse command line arguments
  const args = process.argv.slice(2);

  if (args.length !== 3) {
    console.error('Usage: remote-lat <connect_to> <message_size> <roundtrip_count>');
    console.error('Example: remote-lat tcp://127.0.0.1:5555 64 10000');
    process.exit(1);
  }

  const connectTo = args[0];
  const messageSize = parseInt(args[1], 10);
  const roundtripCount = parseInt(args[2], 10);

  // Validate arguments
  if (isNaN(messageSize) || messageSize <= 0) {
    console.error('Error: message_size must be a positive integer');
    process.exit(1);
  }

  if (isNaN(roundtripCount) || roundtripCount <= 0) {
    console.error('Error: roundtrip_count must be a positive integer');
    process.exit(1);
  }

  try {
    // Create REQ socket
    const socket = new zmq.Request();

    // Connect to server
    socket.connect(connectTo);
    console.log(`Connected to ${connectTo}`);
    console.log(`Message size: ${messageSize} bytes`);
    console.log(`Roundtrip count: ${roundtripCount}`);

    // Prepare message buffer filled with 'X'
    const sendBuffer = Buffer.alloc(messageSize, 'X');

    // Warm-up
    await socket.send(sendBuffer);
    const [warmupMsg] = await socket.receive();
    if (warmupMsg.length !== messageSize) {
      console.error(`Error: Warm-up message size mismatch. Expected ${messageSize}, got ${warmupMsg.length}`);
      socket.close();
      process.exit(1);
    }

    // Start timing (use high-resolution time in nanoseconds)
    const startTime = process.hrtime.bigint();

    // Perform roundtrips
    for (let i = 0; i < roundtripCount; i++) {
      // Send request
      await socket.send(sendBuffer);

      // Receive reply
      const [recvMsg] = await socket.receive();

      // Verify message size
      if (recvMsg.length !== messageSize) {
        console.error(`Error: Message size mismatch at iteration ${i}. Expected ${messageSize}, got ${recvMsg.length}`);
        socket.close();
        process.exit(1);
      }
    }

    // Stop timing
    const endTime = process.hrtime.bigint();

    // Calculate elapsed time in microseconds
    const elapsedNanoseconds = endTime - startTime;
    const elapsedMicroseconds = Number(elapsedNanoseconds / 1000n);

    // Calculate latency (divide by 2 for one-way, not round-trip)
    const latency = elapsedMicroseconds / (roundtripCount * 2);

    // Print results in C++ compatible format
    console.log(`message size: ${messageSize} [B]`);
    console.log(`roundtrip count: ${roundtripCount}`);
    console.log(`average latency: ${latency.toFixed(3)} [us]`);

    // Close socket
    socket.close();
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

main();
