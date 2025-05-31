package mqtt

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	paho "github.com/eclipse/paho.mqtt.golang"
	"github.com/chatapplication/backend/models"
)

// MQTTClient handles MQTT communication
type MQTTClient struct {
	client paho.Client
}

// MessagePayload represents the message payload for MQTT
type MessagePayload struct {
	ID         string    `json:"id"`
	SenderID   string    `json:"sender_id"`
	ReceiverID *string   `json:"receiver_id,omitempty"`
	GroupID    *string   `json:"group_id,omitempty"`
	Content    string    `json:"content"`
	Type       string    `json:"type"`
	Timestamp  time.Time `json:"timestamp"`
}

// NewClient creates a new MQTT client and connects to the broker
func NewClient() (*MQTTClient, error) {
	// Get MQTT broker details from environment variables
	broker := getEnv("MQTT_BROKER", "localhost")
	port := getEnv("MQTT_PORT", "1883")
	clientID := getEnv("MQTT_CLIENT_ID", "go-server")
	username := getEnv("MQTT_USERNAME", "")
	password := getEnv("MQTT_PASSWORD", "")

	// Create MQTT client options
	opts := paho.NewClientOptions()
	opts.AddBroker(fmt.Sprintf("tcp://%s:%s", broker, port))
	opts.SetClientID(clientID)
	if username != "" {
		opts.SetUsername(username)
		opts.SetPassword(password)
	}
	opts.SetKeepAlive(60 * time.Second)
	opts.SetDefaultPublishHandler(defaultMessageHandler)
	opts.SetPingTimeout(1 * time.Second)
	opts.SetAutoReconnect(true)
	opts.SetMaxReconnectInterval(5 * time.Minute)
	opts.SetConnectionLostHandler(connectionLostHandler)
	opts.SetOnConnectHandler(connectHandler)

	// Create and connect client
	client := paho.NewClient(opts)
	token := client.Connect()
	if token.Wait() && token.Error() != nil {
		return nil, token.Error()
	}

	return &MQTTClient{client: client}, nil
}

// PublishDirectMessage publishes a direct message to a user
func (m *MQTTClient) PublishDirectMessage(message *models.Message) error {
	if message.ReceiverID == nil {
		return fmt.Errorf("receiver ID is required for direct messages")
	}

	payload := MessagePayload{
		ID:         message.ID,
		SenderID:   message.SenderID,
		ReceiverID: message.ReceiverID,
		Content:    message.Content,
		Type:       string(message.Type),
		Timestamp:  message.Timestamp,
	}

	return m.publishMessage(fmt.Sprintf("chat/user/%s", *message.ReceiverID), payload)
}

// PublishGroupMessage publishes a message to a group
func (m *MQTTClient) PublishGroupMessage(message *models.Message) error {
	if message.GroupID == nil {
		return fmt.Errorf("group ID is required for group messages")
	}

	payload := MessagePayload{
		ID:        message.ID,
		SenderID:  message.SenderID,
		GroupID:   message.GroupID,
		Content:   message.Content,
		Type:      string(message.Type),
		Timestamp: message.Timestamp,
	}

	return m.publishMessage(fmt.Sprintf("chat/group/%s", *message.GroupID), payload)
}

// publishMessage publishes a message to a topic
func (m *MQTTClient) publishMessage(topic string, payload interface{}) error {
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	token := m.client.Publish(topic, 1, false, payloadBytes)
	if token.Wait() && token.Error() != nil {
		return token.Error()
	}

	return nil
}

// Subscribe subscribes to a topic
func (m *MQTTClient) Subscribe(topic string, callback paho.MessageHandler) error {
	token := m.client.Subscribe(topic, 1, callback)
	if token.Wait() && token.Error() != nil {
		return token.Error()
	}

	return nil
}

// Unsubscribe unsubscribes from a topic
func (m *MQTTClient) Unsubscribe(topic string) error {
	token := m.client.Unsubscribe(topic)
	if token.Wait() && token.Error() != nil {
		return token.Error()
	}

	return nil
}

// Disconnect disconnects from the MQTT broker
func (m *MQTTClient) Disconnect() {
	m.client.Disconnect(250)
}

// Default message handler
func defaultMessageHandler(client paho.Client, msg paho.Message) {
	log.Printf("Received message on topic: %s\nMessage: %s\n", msg.Topic(), string(msg.Payload()))
}

// Connection lost handler
func connectionLostHandler(client paho.Client, err error) {
	log.Printf("Connection lost: %v", err)
}

// Connect handler
func connectHandler(client paho.Client) {
	log.Println("Connected to MQTT broker")
}

// getEnv gets an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}