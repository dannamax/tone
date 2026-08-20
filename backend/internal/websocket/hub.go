package websocket

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

type Client struct {
	ID     string
	UserID string
	Hub    *Hub
	Conn   *websocket.Conn
	Send   chan []byte
}

type Message struct {
	Type    string      `json:"type"`
	Payload interface{} `json:"payload"`
}

type Hub struct {
	mu       sync.RWMutex
	clients  map[string]*Client
	register chan *Client
	unregister chan *Client
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[string]*Client),
		register:   make(chan *Client, 256),
		unregister: make(chan *Client, 256),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client.UserID] = client
			h.mu.Unlock()
			log.Printf("[WS] User %s connected", client.UserID)

		case client := <-h.unregister:
			h.mu.Lock()
			if c, ok := h.clients[client.UserID]; ok && c == client {
				delete(h.clients, client.UserID)
				close(client.Send)
			}
			h.mu.Unlock()
			log.Printf("[WS] User %s disconnected", client.UserID)
		}
	}
}

func (h *Hub) SendToUser(userID string, msg Message) error {
	h.mu.RLock()
	client, ok := h.clients[userID]
	h.mu.RUnlock()

	if !ok {
		return fmt.Errorf("user %s not connected", userID)
	}

	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}

	select {
	case client.Send <- data:
		return nil
	default:
		return fmt.Errorf("user %s send buffer full", userID)
	}
}

func (h *Hub) SendToUsers(userIDs []string, msg Message) {
	for _, id := range userIDs {
		h.SendToUser(id, msg)
	}
}

const (
	MsgTypeTaskClaimed   = "task_claimed"
	MsgTypeTaskSubmitted = "task_submitted"
	MsgTypeTaskConfirmed = "task_confirmed"
	MsgTypeTaskDisputed  = "task_disputed"
	MsgTypeTaskReleased  = "task_released"
	MsgTypeTaskRefunded  = "task_refunded"
	MsgTypeTaskExpired   = "task_expired"
	MsgTypeBalanceChange = "balance_change"
	MsgTypeDisputeResult = "dispute_result"
)
