#!/usr/bin/env node
/*
 * ZeroMQ Node.js Latency Test - Local (Server)
 *
 * Echo server using REP socket.
 * Pattern: REP -> REQ (synchronous request-reply)
 *
 * Usage: node local-lat.js <bind_to> <message_size> <roundtrip_count>
 * Example: node local-lat.js tcp://*:5555 64 10000
 */

import zmq from 'zeromq';

async function main() {
  // Parse command line arguments
  const args = process.argv.slice(2);

  if (args.length !== 3) {
    console.error('Usage: local-lat <bind_to> <message_size> <roundtrip_count>');
    console.error('Example: local-lat tcp://*:5555 64 10000');
    process.exit(1);
  }

  const bindTo = args[0];
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
    // Create REP socket
    const socket = new zmq.Reply();

    // Bind to endpoint
    await socket.bind(bindTo);
    console.log(`Listening on ${bindTo}`);
    console.log(`Message size: ${messageSize} bytes`);
    console.log(`Roundtrip count: ${roundtripCount}`);
    console.log('Waiting for messages...');

    // Warm-up
    const [warmupMsg] = await socket.receive();
    if (warmupMsg.length !== messageSize) {
      console.error(`Error: Warm-up message size mismatch. Expected ${messageSize}, got ${warmupMsg.length}`);
      socket.close();
      process.exit(1);
    }
    await socket.send(warmupMsg);

    // Echo loop - receive and send back (roundtrip_count times)
    for (let i = 0; i < roundtripCount; i++) {
      // Receive message
      const [msg] = await socket.receive();

      // Verify message size
      if (msg.length !== messageSize) {
        console.error(`Error: Message size mismatch at iteration ${i}. Expected ${messageSize}, got ${msg.length}`);
        socket.close();
        process.exit(1);
      }

      // Echo back (send the same message)
      await socket.send(msg);
    }

    console.log(`\nCompleted ${roundtripCount} roundtrips.`);

    // Close socket
    socket.close();
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

main();
