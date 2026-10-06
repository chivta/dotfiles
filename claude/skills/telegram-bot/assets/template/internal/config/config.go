package config

import (
	"fmt"
	"time"

	"github.com/caarlos0/env/v11"
	"github.com/go-playground/validator/v10"
	"github.com/joho/godotenv"
)

// Config is the fully validated runtime configuration of the service. Every
// field is documented here rather than only in .example.env, because this is
// the struct people read when they wonder what a setting does.
type Config struct {
	// BotToken is the Telegram bot token from @BotFather.
	BotToken string `env:"BOT_TOKEN" validate:"required"`
	// AllowedUsers pins who may use the bot. Empty means anyone may.
	AllowedUsers []int64 `env:"ALLOWED_USERS" envSeparator:","`

	// DBPath is the SQLite file. It belongs on persistent storage.
	DBPath string `env:"DB_PATH" validate:"required"`

	// Workers bounds how many jobs run at once across all users, and QueueSize
	// how many may wait. Together they keep one busy user from stalling
	// everyone else.
	Workers   int `env:"WORKERS"    validate:"required,min=1,max=32"`
	QueueSize int `env:"QUEUE_SIZE" validate:"required,min=1"`

	// UserRatePerHour and UserBurst are the per-user token bucket. UserBurst
	// doubles as the cap on how many jobs one user may have in flight.
	UserRatePerHour int `env:"USER_RATE_PER_HOUR" validate:"required,min=1"`
	UserBurst       int `env:"USER_BURST"         validate:"required,min=1"`

	// JobTimeout bounds a single unit of work.
	JobTimeout time.Duration `env:"JOB_TIMEOUT" validate:"required,min=1s"`

	HTTPAddr string `env:"HTTP_ADDR" validate:"required"`
	LogLevel string `env:"LOG_LEVEL" validate:"required,oneof=debug info warn error"`
}

// Load reads .env when present, overlays the process environment and validates
// the result. Any problem is fatal for the caller: a bot that starts with a
// half-valid config fails later and more confusingly, in front of users.
func Load() (Config, error) {
	_ = godotenv.Load()

	// Defaults are set before parsing, so the environment only has to carry
	// what actually differs from them.
	cfg := Config{
		DBPath:          "data/mybot.db",
		Workers:         3,
		QueueSize:       64,
		UserRatePerHour: 20,
		UserBurst:       3,
		JobTimeout:      5 * time.Minute,
		HTTPAddr:        ":8080",
		LogLevel:        "info",
	}

	err := env.Parse(&cfg)
	if err != nil {
		return Config{}, fmt.Errorf("parse env: %w", err)
	}

	err = validator.New().Struct(cfg)
	if err != nil {
		return Config{}, fmt.Errorf("validate config: %w", err)
	}

	return cfg, nil
}
