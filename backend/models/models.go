package models

import (
	"time"

	"gorm.io/gorm"
)

// User represents a user in the system
type User struct {
	ID        string    `json:"id" gorm:"primaryKey"`
	Username  string    `json:"username" gorm:"uniqueIndex;not null"`
	Email     string    `json:"email" gorm:"uniqueIndex;not null"`
	Password  string    `json:"-" gorm:"not null"`
	AvatarURL *string   `json:"avatar_url"`
	LastSeen  time.Time `json:"last_seen"`
	IsOnline  bool      `json:"is_online" gorm:"default:false"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// MessageType represents the type of message
type MessageType string

const (
	TextMessage   MessageType = "text"
	ImageMessage  MessageType = "image"
	FileMessage   MessageType = "file"
	SystemMessage MessageType = "system"
)

// Message represents a message in the system
type Message struct {
	ID         string      `json:"id" gorm:"primaryKey"`
	SenderID   string      `json:"sender_id" gorm:"index;not null"`
	ReceiverID *string     `json:"receiver_id" gorm:"index"`
	GroupID    *string     `json:"group_id" gorm:"index"`
	Content    string      `json:"content" gorm:"not null"`
	Type       MessageType `json:"type" gorm:"default:'text'"`
	IsRead     bool        `json:"is_read" gorm:"default:false"`
	Timestamp  time.Time   `json:"timestamp"`
	CreatedAt  time.Time   `json:"created_at"`
	UpdatedAt  time.Time   `json:"updated_at"`

	// Relations
	Sender   User   `json:"sender" gorm:"foreignKey:SenderID"`
	Receiver *User  `json:"receiver,omitempty" gorm:"foreignKey:ReceiverID"`
	Group    *Group `json:"group,omitempty" gorm:"foreignKey:GroupID"`
}

// Group represents a chat group
type Group struct {
	ID          string    `json:"id" gorm:"primaryKey"`
	Name        string    `json:"name" gorm:"not null"`
	Description *string   `json:"description"`
	AvatarURL   *string   `json:"avatar_url"`
	CreatorID   string    `json:"creator_id" gorm:"index;not null"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`

	// Relations
	Creator User        `json:"creator" gorm:"foreignKey:CreatorID"`
	Members []GroupUser `json:"members" gorm:"foreignKey:GroupID"`
}

// GroupUser represents the many-to-many relationship between users and groups
type GroupUser struct {
	GroupID   string    `json:"group_id" gorm:"primaryKey"`
	UserID    string    `json:"user_id" gorm:"primaryKey"`
	JoinedAt  time.Time `json:"joined_at"`
	IsAdmin   bool      `json:"is_admin" gorm:"default:false"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	// Relations
	User User `json:"user" gorm:"foreignKey:UserID"`
}

// AutoMigrate automatically migrates the database schema
func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(
		&User{},
		&Message{},
		&Group{},
		&GroupUser{},
	)
}
