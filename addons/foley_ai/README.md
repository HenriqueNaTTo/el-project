# Foley AI for Godot

Generate and import Foley AI sound effects directly inside the Godot editor.

## Requirements

- Godot 4.6
- A Foley AI API key

## Features

- Docked generator panel for the full generation workflow
- Quick Generate dialog from the FileSystem context menu
- Variation generation from previously generated clips
- Prompt presets, recent prompts, and batch prompt queues
- Token/account lookup and retry handling for transient API failures
- Import pipeline with deterministic naming and metadata sidecars
- Preview, reveal, and copy-path actions for imported clips

## Installation

1. Copy the `addons/foley_ai` folder into your project.
2. Enable the plugin in `Project Settings > Plugins`.
3. Save your Foley AI API key in the plugin panel or set `foley_ai/api_key`.

## Notes

- Output defaults to `res://audio/foley_ai`.
- Metadata is stored as hidden `.foley.json` sidecars beside each generated clip.
- This is an editor-only addon.
