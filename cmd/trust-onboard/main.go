package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"trust-onboard/internal/cert"
	"trust-onboard/internal/config"
	"trust-onboard/internal/server"
)

func main() {
	log.SetFlags(log.Ldate | log.Ltime | log.LUTC)
	if err := run(os.Args[1:]); err != nil {
		log.Printf("error: %v", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) == 0 {
		return usageError("missing command")
	}

	switch args[0] {
	case "serve":
		return runServe(args[1:])
	case "generate":
		return runGenerate(args[1:])
	case "validate":
		return runValidate(args[1:])
	case "print-fingerprint":
		return runPrintFingerprint(args[1:])
	case "help", "-h", "--help":
		printUsage()
		return nil
	default:
		return usageError(fmt.Sprintf("unknown command %q", args[0]))
	}
}

func runServe(args []string) error {
	fs := flag.NewFlagSet("serve", flag.ContinueOnError)
	configPath := fs.String("config", "config.yaml", "Path to configuration file")
	if err := fs.Parse(args); err != nil {
		return err
	}

	bundle, err := loadBundle(*configPath)
	if err != nil {
		return err
	}

	log.Printf("validated configuration for %q", bundle.Config.SiteTitle)

	handler, err := server.New(bundle)
	if err != nil {
		return err
	}

	httpServer := &http.Server{
		Addr:              bundle.Config.ListenAddress,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      20 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	errCh := make(chan error, 1)
	go func() {
		log.Printf("starting HTTP server on %s", bundle.Config.ListenAddress)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
			return
		}
		errCh <- nil
	}()

	select {
	case <-ctx.Done():
		log.Printf("shutdown signal received")
	case err := <-errCh:
		return err
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("shutdown server: %w", err)
	}

	if err := <-errCh; err != nil {
		return err
	}

	log.Printf("server stopped cleanly")
	return nil
}

func runGenerate(args []string) error {
	fs := flag.NewFlagSet("generate", flag.ContinueOnError)
	configPath := fs.String("config", "config.yaml", "Path to configuration file")
	outputDir := fs.String("output-dir", "./dist", "Output directory")
	if err := fs.Parse(args); err != nil {
		return err
	}

	bundle, err := loadBundle(*configPath)
	if err != nil {
		return err
	}

	if err := os.MkdirAll(*outputDir, 0o755); err != nil {
		return fmt.Errorf("create output directory: %w", err)
	}

	if err := bundle.WriteArtifacts(*outputDir); err != nil {
		return err
	}

	log.Printf("generated artifacts in %s", *outputDir)
	return nil
}

func runValidate(args []string) error {
	fs := flag.NewFlagSet("validate", flag.ContinueOnError)
	configPath := fs.String("config", "config.yaml", "Path to configuration file")
	if err := fs.Parse(args); err != nil {
		return err
	}

	bundle, err := loadBundle(*configPath)
	if err != nil {
		return err
	}

	log.Printf("configuration is valid")
	log.Printf("site title: %s", bundle.Config.SiteTitle)
	log.Printf("base URL: %s", bundle.Config.BaseURL)
	log.Printf("fingerprint: %s", bundle.Fingerprint)
	return nil
}

func runPrintFingerprint(args []string) error {
	fs := flag.NewFlagSet("print-fingerprint", flag.ContinueOnError)
	configPath := fs.String("config", "config.yaml", "Path to configuration file")
	if err := fs.Parse(args); err != nil {
		return err
	}

	bundle, err := loadBundle(*configPath)
	if err != nil {
		return err
	}

	fmt.Println(bundle.Fingerprint)
	return nil
}

func loadBundle(configPath string) (*cert.Bundle, error) {
	absConfig, err := filepath.Abs(configPath)
	if err != nil {
		return nil, fmt.Errorf("resolve config path: %w", err)
	}

	cfg, err := config.Load(absConfig)
	if err != nil {
		return nil, err
	}

	bundle, err := cert.LoadBundle(cfg)
	if err != nil {
		return nil, err
	}

	return bundle, nil
}

func usageError(msg string) error {
	printUsage()
	return errors.New(msg)
}

func printUsage() {
	lines := []string{
		"trust-onboard distributes public trust material for step-ca deployments.",
		"",
		"Usage:",
		"  trust-onboard serve --config config.yaml",
		"  trust-onboard generate --config config.yaml --output-dir ./dist",
		"  trust-onboard validate --config config.yaml",
		"  trust-onboard print-fingerprint --config config.yaml",
	}
	fmt.Fprintln(os.Stderr, strings.Join(lines, "\n"))
}
