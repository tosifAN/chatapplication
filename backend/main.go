package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"backend/config"
	"backend/controllers"
	"backend/middleware"
	"backend/models"
	"backend/mqtt"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(".env"); err != nil {
		log.Println("Warning: No .env file found")
	}

	// Initialize database connection
	db, err := config.InitDB()
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Auto migrate database models
	if err := models.AutoMigrate(db); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	// Initialize MQTT client
	mqttClient, err := mqtt.NewClient()
	if err != nil {
		log.Fatalf("Failed to connect to MQTT broker: %v", err)
	}
	defer mqttClient.Disconnect()

	// Set up Gin router
	router := gin.Default()

	// Configure CORS
	router.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	// Initialize controllers
	authController := controllers.NewAuthController(db)
	userController := controllers.NewUserController(db)
	messageController := controllers.NewMessageController(db, mqttClient)
	groupController := controllers.NewGroupController(db, mqttClient)

	// API routes
	api := router.Group("/api")
	{
		// Auth routes
		auth := api.Group("/auth")
		{
			auth.POST("/register", authController.Register)
			auth.POST("/login", authController.Login)
		}

		// User routes
		users := api.Group("/users")
		users.Use(middleware.AuthMiddleware())
		{
			users.GET("/search", userController.SearchUsers)
			users.GET("/:id", userController.GetUser)
			users.PUT("/:id", userController.UpdateUser)
			users.GET("/:id/groups", userController.GetUserGroups)
			users.GET("/:id/recent-chats", userController.GetRecentChats) // <-- Add this line
		}

		// Message routes
		messages := api.Group("/messages")
		messages.Use(middleware.AuthMiddleware())
		{
			messages.GET("/direct/:userId/:otherUserId", messageController.GetDirectMessages)
			messages.POST("/direct", messageController.SendDirectMessage)
			messages.GET("/group/:groupId", messageController.GetGroupMessages)
			messages.POST("/group", messageController.SendGroupMessage)
			messages.POST("/mark-as-read", messageController.MarkMessagesAsRead)
			messages.GET("/direct/unseen-count/:userId/:otherUserId", messageController.GetUnseenMessagesBWCount)
		}

		// Group routes
		groups := api.Group("/groups")
		groups.Use(middleware.AuthMiddleware())
		{
			groups.POST("", groupController.CreateGroup)
			groups.GET("/:id", groupController.GetGroup)
			groups.PUT("/:id", groupController.UpdateGroup)
			groups.POST("/:id/members", groupController.AddMember)
			groups.DELETE("/:id/members/:userId", groupController.RemoveMember)
			groups.DELETE("/:id", groupController.DeleteGroup) // <-- Add this line
		}
	}

	// Get port from environment variable or use default
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Start server
	serverAddr := fmt.Sprintf(":%s", port)
	log.Printf("Server running on http://localhost%s", serverAddr)
	if err := router.Run(serverAddr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
