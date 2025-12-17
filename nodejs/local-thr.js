#!/usr/bin/env node
/*
 * ZeroMQ Node.js Throughput Test - Local (Receiver)
 *
 * Receives messages using PULL socket and measures throughput.
 * Pattern: PULL -> PUSH (unidirectional data flow)
 *
 * Usage: node local-thr.js <bind_to> <message_size> <message_count>
 * Example: node local-thr.js tcp://*:5556 64 1000000
 */

import zmq from 'zeromq';

async function main() {
  // Parse command line arguments
  const args = process.argv.slice(2);

  if (args.length !== 3) {
    console.error('Usage: local-thr <bind_to> <message_size> <message_count>');
    console.error('Example: local-thr tcp://*:5556 64 1000000');
    process.exit(1);
  }

  const bindTo = args[0];
  const messageSize = parseInt(args[1], 10);
  const messageCount = parseInt(args[2], 10);

  // Validate arguments
  if (isNaN(messageSize) || messageSize <= 0) {
    console.error('Error: message_size must be a positive integer');
    process.exit(1);
  }

  if (isNaN(messageCount) || messageCount <= 0) {
    console.error('Error: message_count must be a positive integer');
    process.exit(1);
  }

  try {
    // Create PULL socket
    const socket = new zmq.Pull();

    // Bind to endpoint
    await socket.bind(bindTo);
    console.log(`Listening on ${bindTo}`);
    console.log(`Message size: ${messageSize} bytes`);
    console.log(`Message count: ${messageCount}`);
    console.log('Waiting for messages...');

    // Receive first message (warm-up, start timing after first message)
    const [firstMsg] = await socket.receive();

    if (firstMsg.length !== messageSize) {
      console.error(`Error: Message size mismatch. Expected ${messageSize}, got ${firstMsg.length}`);
      socket.close();
      process.exit(1);
    }

    console.log('First message received. Starting measurement...');

    // Start timing (use high-resolution time in nanoseconds)
    const startTime = process.hrtime.bigint();

    // Receive remaining messages
    for (let i = 1; i < messageCount; i++) {
      const [msg] = await socket.receive();

      // Verify message size
      if (msg.length !== messageSize) {
        console.error(`Error: Message size mismatch at message ${i}. Expected ${messageSize}, got ${msg.length}`);
        socket.close();
        process.exit(1);
      }

      // Progress indicator (every 10%)
      if (messageCount > 100 && (i + 1) % Math.floor(messageCount / 10) === 0) {
        const progress = Math.floor(((i + 1) * 100) / messageCount);
        console.log(`Progress: ${progress}% (${i + 1}/${messageCount})`);
      }
    }

    // Stop timing
    const endTime = process.hrtime.bigint();

    // Calculate elapsed time in microseconds
    const elapsedNanoseconds = endTime - startTime;
    const elapsedMicroseconds = Number(elapsedNanoseconds / 1000n);

    // Calculate throughput
    const elapsedSeconds = elapsedMicroseconds / 1_000_000.0;
    const throughput = (messageCount - 1) / elapsedSeconds;
    const megabits = (throughput * messageSize * 8) / 1_000_000.0;

    // Print results in C++ compatible format
    console.log();
    console.log(`message size: ${messageSize} [B]`);
    console.log(`message count: ${messageCount}`);
    console.log(`mean throughput: ${Math.round(throughput)} [msg/s]`);
    console.log(`mean throughput: ${megabits.toFixed(3)} [Mb/s]`);

    // Close socket
    socket.close();
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

main();
