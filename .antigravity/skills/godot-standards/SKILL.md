**name: "godot-4-gdscript-standards" activation: "always-on" priority: "highest" description: "Core architectural rules and GDScript 4.3 syntax requirements for the 2D puzzle-platformer." keywords: \["godot", "gdscript", "node", "scene", "physics", "signal", "architecture"\]**

# **Godot 4.3 GDScript Architectural Standards**

You are an elite Godot 4.3 AI Assistant. All generated code must strictly adhere to the following deterministic rules to ensure performance and maintainability.

## **Core Principles**

1. **Static Typing:** Use explicit type hints everywhere. Avoid untyped variables such as @onready var x \= $Node. Always use typed variables like @onready var x: Sprite2D \= $Node to ensure IDE autocomplete functionality, improve performance, and prevent runtime crashes.16  
2. **Signal-Driven Architecture:** Follow the paradigm of "signal up, call down." Children must never call methods directly on their parent nodes, as this creates tight, fragile coupling. Parents invoke methods on children; children emit signals that parents listen to.16  
3. **Node References:** Use %UniqueName for deep node paths rather than fragile $A/B/C/D hierarchies. If a node path changes, unique names prevent the script from breaking.16

## **Specific Anti-Patterns to Avoid**

* **Polling in \_process:** Do not check if state \== condition every frame if the state rarely changes. This wastes CPU cycles. Use signals to push state changes asynchronously.16  
* **Magic Numbers:** Extract speed, gravity, and jump velocity into @export var properties to allow adjustment from the Godot Editor inspector without altering the codebase.16  
* **Orphan Nodes:** Ensure queue\_free() is called on projectiles and temporary nodes. Do not use node\!= null to check if a node exists after freeing; use is\_instance\_valid(node) to prevent accessing freed memory.16

## **Game Architecture Constraints**

* The project utilizes a Global GameManager AutoLoad (Singleton) located at res://autoloads/game\_manager.gd.  
* All player state (lives, collected items, unlocked abilities) must be routed through the GameManager rather than stored locally on the player controller.  
* Physics calculations and continuous movement logic must exclusively reside in \_physics\_process(delta).  
* Visual updates, timers, and non-colliding logic should reside in \_process(delta).

### **1.4. Bridging the Engine Gap: Godot MCP Server Implementation**

A fundamental limitation of agentic AI in game development is the inability of the LLM to visually test its own output. While an agent can write the code for a jump mechanic, it cannot "play" the game to verify if the jump height is sufficient to clear a specific gap, nor can it ascertain if a UI button correctly triggers a scene transition.17 Automated testing in frameworks like three.js is simpler because developers can define behavioral assertions, but game correctness involves a highly subjective surface that requires visual validation.17

To resolve this limitation, developers must implement a Model Context Protocol (MCP) server specific to Godot 4.x. The MCP server acts as an intermediary, giving AI assistants full control over the running Godot game engine through standard JSON-RPC 2.0 communication.19

This specific architecture operates by running a Node.js server that communicates over WebSocket (typically port 6505\) with a lightweight UDP bridge injected as an AutoLoad plugin directly into the Godot editor process.18 Unlike external scripts that simply manipulate .tscn files headlessly, this runtime bridge allows the AI to interact with the live SceneTree.18 Through this protocol, the AI agent gains access to over 149 distinct tools spanning 3D/2D rendering, UI controls, audio effects, and signal management.19

Crucially, the MCP server empowers the AI to simulate user input—executing batched key presses, mouse clicks, and Godot action presses—to navigate menus and test gameplay mechanics.18 It can walk the live scene tree to discover UI elements, retrieving every visible Control node along with its position, text content, and interactive state.18 Furthermore, it allows the agent to compile and execute arbitrary GDScript at runtime, meaning the AI can apply fixes dynamically.18

By taking viewport screenshots at any point during gameplay, the system allows a separate vision-capable agent (such as Gemini 3 Pro) to view the rendered output and compare it against reference images.17 This effectively closes the testing loop. The AI assistant can build a scene, run the project, simulate a sequence of inputs, capture the visual result, verify the mechanics, and autonomously rewrite the script if the functionality fails—transforming the IDE from a code generator into a comprehensive, automated QA tester.18