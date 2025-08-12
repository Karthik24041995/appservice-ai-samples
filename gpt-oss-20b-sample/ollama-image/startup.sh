#!/usr/bin/env bash
 
# Start Ollama in the background
ollama serve &
sleep 5

# Pull and run gpt-oss:20b
ollama pull gpt-oss:20b
 
# Restart ollama and run it in to foreground.
pkill -f "ollama"
ollama serve