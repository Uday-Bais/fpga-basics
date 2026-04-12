# FPGA Basics

This repository provides introductory learning material for FPGA development, along with a practical temperature measurement project implemented on the **Nexys A7-100T (Artix-7)** development board. The project utilizes the onboard **ADT7420** temperature sensor.

## Repository Structure

### 1. `temperature_with_7segment/`

This directory contains the complete implementation of the temperature measurement system, including:

- ADT7420 temperature sensor interface (I²C protocol)  
- I²C master controller  
- Clock divider module  
- Temperature data processing logic  
- UART transmission module  
- Top-level integration module  

The primary objective of this module is to read temperature data from the ADT7420 sensor and display the processed output on the onboard seven-segment display.

### 2. `codes/`

This directory includes foundational FPGA/VHDL examples for learning and reference purposes:

- Full adder implementation.  
- Clock utilization example.
- Seven-segment display interfacing with switches(Binary to hexadecimal) .

## Additional Resources

- `Nexys-A7-100T-Master.xdc` — Official constraints file for the Nexys A7-100T board  
- *Digital Design and Computer Architecture* by David Harris and Sarah Harris — Reference textbook  
- *Principles and Structures of FPGAs* — Supplementary reference material  
