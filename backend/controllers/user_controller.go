package controllers

import (
	"net/http"
	"time"

	"backend/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// UserController handles user-related requests
type UserController struct {
	db *gorm.DB
}

// NewUserController creates a new user controller
func NewUserController(db *gorm.DB) *UserController {
	return &UserController{db: db}
}

// GetUser gets a user by ID
func (uc *UserController) GetUser(c *gin.Context) {
	userID := c.Param("id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
		return
	}

	// Get the authenticated user ID from the context
	authUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Find user by ID
	var user models.User
	result := uc.db.First(&user, "id = ?", userID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Update last seen if this is the authenticated user
	if authUserID == userID {
		user.LastSeen = time.Now()
		user.IsOnline = true
		uc.db.Save(&user)
	}

	c.JSON(http.StatusOK, user)
}

// SearchUsers searches for users by username or email
func (uc *UserController) SearchUsers(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Search query is required"})
		return
	}

	// Search for users by username or email
	var users []models.User
	result := uc.db.Where("username LIKE ? OR email LIKE ?", "%"+query+"%", "%"+query+"%").Limit(20).Find(&users)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search users"})
		return
	}

	c.JSON(http.StatusOK, users)
}

// UpdateUserRequest represents the request body for updating a user
type UpdateUserRequest struct {
	Username  *string `json:"username"`
	AvatarURL *string `json:"avatar_url"`
}

// UpdateUser updates a user's profile
func (uc *UserController) UpdateUser(c *gin.Context) {
	userID := c.Param("id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
		return
	}

	// Get the authenticated user ID from the context
	authUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Check if the authenticated user is updating their own profile
	if authUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only update your own profile"})
		return
	}

	// Parse request body
	var req UpdateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Find user by ID
	var user models.User
	result := uc.db.First(&user, "id = ?", userID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Update user fields if provided
	if req.Username != nil {
		// Check if username is already taken
		var existingUser models.User
		result = uc.db.Where("username = ? AND id != ?", *req.Username, userID).First(&existingUser)
		if result.Error == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "Username is already taken"})
			return
		}

		user.Username = *req.Username
	}

	if req.AvatarURL != nil {
		user.AvatarURL = req.AvatarURL
	}

	// Update last seen and updated at
	user.LastSeen = time.Now()
	user.UpdatedAt = time.Now()

	// Save user
	result = uc.db.Save(&user)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user"})
		return
	}

	c.JSON(http.StatusOK, user)
}

// GetUserGroups gets all groups that a user is a member of
func (uc *UserController) GetUserGroups(c *gin.Context) {
	userID := c.Param("id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
		return
	}

	// Get the authenticated user ID from the context
	_, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Check if the user exists
	var user models.User
	result := uc.db.First(&user, "id = ?", userID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Get all groups that the user is a member of
	var groupUsers []models.GroupUser
	result = uc.db.Where("user_id = ?", userID).Find(&groupUsers)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get user groups"})
		return
	}

	// Get group details for each group
	var groups []models.Group
	for _, groupUser := range groupUsers {
		var group models.Group
		result = uc.db.Preload("Creator").First(&group, "id = ?", groupUser.GroupID)
		if result.Error == nil {
			groups = append(groups, group)
		}
	}

	c.JSON(http.StatusOK, groups)
}
