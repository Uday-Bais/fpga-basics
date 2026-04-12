# FPGA Basics

This repository contains beginner FPGA learning material and a practical temperature-measurement project for the **Nexys A7-100T (Artix-7)** board using the onboard **ADT7420** temperature sensor.

## Repository Structure

### 1) `temperature_with_7segment/`
Files for the temperature-measurement project:
- ADT7420 sensor interface (I2C)
- I2C master logic
- Clock divider
- Temperature processing
- UART transmitter
- Top-level integration module

This folder is focused on reading temperature data from ADT7420 and displaying/processing it on FPGA.

### 2) `codes/`
Basic starter FPGA/VHDL examples:
- Full adder implementations
- Clock usage example
- 7-segment + switch example

## Other Files

- `Nexys-A7-100T-Master.xdc` – official board constraints file
- `David_Harris_Sarah_Harris-Digital_Design_and_Computer_Architecture-EN.pdf` – study reference
- `pdfcoffee.com_principles-and-structures-of-fpgas-4-pdf-free.pdf` – study reference
