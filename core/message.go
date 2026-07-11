package main

import "time"

const (
	messageBatchInterval = 16 * time.Millisecond
	messageBatchSize     = 32
	messageQueueSize     = 256
)

var messageQueue = make(chan Message, messageQueueSize)

func init() {
	go runMessageBatcher(messageQueue, sendMessageBatch)
}

func sendMessage(message Message) {
	select {
	case messageQueue <- message:
		return
	default:
	}

	// Event delivery must never block the core. Keep recent state by evicting
	// the oldest queued event when producers outrun the UI.
	select {
	case <-messageQueue:
	default:
	}
	select {
	case messageQueue <- message:
	default:
	}
}

func runMessageBatcher(messages <-chan Message, send func([]Message)) {
	ticker := time.NewTicker(messageBatchInterval)
	defer ticker.Stop()

	batch := make([]Message, 0, messageBatchSize)
	flush := func() {
		if len(batch) == 0 {
			return
		}
		current := append([]Message(nil), batch...)
		batch = batch[:0]
		send(current)
	}

	for {
		select {
		case message, ok := <-messages:
			if !ok {
				flush()
				return
			}
			batch = append(batch, message)
			if len(batch) >= messageBatchSize {
				flush()
			}
		case <-ticker.C:
			flush()
		}
	}
}
