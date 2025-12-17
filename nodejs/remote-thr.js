#!/usr/bin/env node
/*
 * ZeroMQ Node.js Throughput Test - Remote (Sender)
 *
 * Sends messages using PUSH socket for throughput measurement.
 * Pattern: PUSH -> PULL (unidirectional data flow)
 *
 * Usage: node remote-thr.js <connect_to> <message_size> <message_count>
 * Example: node remote-thr.js tcp://127.0.0.1:5556 64 1000000
 */

import zmq from 'zeromq';

// Helper function to sleep
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  // Parse command line arguments
  const args = process.argv.slice(2);

  if (args.length !== 3) {
    console.error('Usage: remote-thr <connect_to> <message_size> <message_count>');
    console.error('Example: remote-thr tcp://127.0.0.1:5556 64 1000000');
    process.exit(1);
  }

  const connectTo = args[0];
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
    // Create PUSH socket
    const socket = new zmq.Push();

    // Connect to receiver
    socket.connect(connectTo);
    console.log(`Connected to ${connectTo}`);
    console.log(`Message size: ${messageSize} bytes`);
    console.log(`Message count: ${messageCount}`);

    // Wait for connection to establish
    await sleep(100);

    // Prepare message buffer filled with 'X'
    const buffer = Buffer.alloc(messageSize, 'X');

    console.log('Sending messages...');

    // Send messages
    for (let i = 0; i < messageCount; i++) {
      await socket.send(buffer);

      // Progress indicator (every 10%)
      if (messageCount > 100 && (i + 1) % Math.floor(messageCount / 10) === 0) {
        const progress = Math.floor(((i + 1) * 100) / messageCount);
        console.log(`Progress: ${progress}% (${i + 1}/${messageCount})`);
      }
    }

    const totalDataMB = (messageSize * messageCount) / (1024 * 1024);
    console.log();
    console.log(`Sent ${messageCount} messages successfully.`);
    console.log(`Total data sent: ${totalDataMB.toFixed(2)} MB`);

    // Give time for messages to be delivered
    await sleep(100);

    // Close socket
    socket.close();
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

main();
