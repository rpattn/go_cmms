// internal/config/config.go
package config

import (
	"strings"
	"time"

	"github.com/spf13/viper"
)

type Config struct {
	BaseURL  string `mapstructure:"base_url"`
	Database struct {
		URL string `mapstructure:"url"`
	} `mapstructure:"database"`
	Microsoft struct {
		ClientID     string `mapstructure:"client_id"`
		ClientSecret string `mapstructure:"client_secret"`
		TenantID     string `mapstructure:"tenant_id"`
	} `mapstructure:"microsoft"`
	Google struct {
		ClientID     string `mapstructure:"client_id"`
		ClientSecret string `mapstructure:"client_secret"`
	} `mapstructure:"google"`
	Github struct {
		ClientID     string `mapstructure:"client_id"`
		ClientSecret string `mapstructure:"client_secret"`
	} `mapstructure:"github"`
	Auth struct {
		OIDCCacheDir        string        `yaml:"oidcCacheDir"`
		OIDCRefreshInterval time.Duration `yaml:"oidcRefreshInterval"` // ← parseable duration
	} `yaml:"auth"`
}

func Load() Config {
	viper.SetDefault("microsoft.tenant_id", "organizations")

	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.AddConfigPath("..")
	_ = viper.ReadInConfig()

	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	viper.AutomaticEnv()

	// explicit bindings
	_ = viper.BindEnv("base_url", "BASE_URL")
	_ = viper.BindEnv("database.url", "DATABASE_URL")
	_ = viper.BindEnv("microsoft.client_id", "MICROSOFT_CLIENT_ID")
	_ = viper.BindEnv("microsoft.client_secret", "MICROSOFT_CLIENT_SECRET")
	_ = viper.BindEnv("microsoft.tenant_id", "MICROSOFT_TENANT_ID")
	_ = viper.BindEnv("google.client_id", "GOOGLE_CLIENT_ID")
	_ = viper.BindEnv("google.client_secret", "GOOGLE_CLIENT_SECRET")
	_ = viper.BindEnv("github.client_id", "GITHUB_CLIENT_ID")
	_ = viper.BindEnv("github.client_secret", "GITHUB_CLIENT_SECRET")

	var c Config
	if err := viper.Unmarshal(&c); err != nil {
		panic("config error: " + err.Error())
	}
	if c.BaseURL == "" {
		panic("config error: base_url/BASE_URL required")
	}
	return c
}
