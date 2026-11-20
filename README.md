# Six power electronics experiments

Keep these five files together in a writable MATLAB Drive folder. Set that folder as MATLAB's Current Folder or put it on the MATLAB path. In MATLAB Online, run one of these commands.

```matlab
pe_run('smoke')  % six representative points
pe_run           % representatives plus the scans (31 cases total)
```

MATLAB and Simulink are required. The model uses a Level-2 MATLAB S-Function for discrete ideal-device state updates. MATLAB Coder and Simscape Electrical are optional and are not invoked. Opening an exported .slx directly requires adding the adjacent source folder to the MATLAB path so Simulink resolves pe_switching.m. Exported .slx files store the representative operating points. The runner sets model-workspace variables alphaDeg, loadMode (1 = R, 2 = RL, 3 = RL with freewheel diode) and duty for each simulation.

Each invocation creates a new UTC-stamped directory and ZIP under the current folder. Download pe_live_results.zip for the latest run. The UTC-stamped ZIPs remain available for prior runs. Inspect manifest.json and run_log.txt for failed cases or image exports. The representative reference checks are sanity comparisons and preserve measurements when a reading falls outside the expected range.

| Model | Representative | Additional cases when using pe_run |
| --- | --- | --- |
| 01 single-phase bridge | 01_rl_a60 | R, RL, RL + freewheel at 0, 30, 60, 90, 120 degrees |
| 02 three-phase bridge | 02_rl_a90 | R and RL at 0, 30, 60, 90 degrees |
| 03 voltage-source inverter | 03_rl | |
| 04 current-source inverter | 04_rc | |
| 05 inverting buck-boost | 05_d50 | Duty 0.30, 0.70 |
| 06 inverting Cuk | 06_d50 | Duty 0.30, 0.70 |

## ZIP contents

- models/pe_NN_<name>.slx stores the six Simulink models at their representative parameters.
- diagrams/NN_simulink.png captures the root-level Simulink block diagram. diagrams/NN_circuit.png presents the corresponding ideal switching schematic.
- waveforms/<case_id>.png plots the logged steady-window samples. data/<case_id>.csv contains those samples and data/<case_id>.mat keeps the complete Simulink root-output trace and the case parameters.
- summary.csv contains per-case measurement statistics, simulation step, stop time, and runtime. manifest.json includes channel labels and paths for automated report ingestion. environment.json records MATLAB, Simulink, platform, and run identifiers. run_log.txt lists the simulations and export outcomes.
- source/ contains this README and the four MATLAB source files.

The CSV columns are t_s, channel_1, output_V, current_A and auxiliary. Time is relative to the start of the retained steady window. The CSV preserves the logged values at original timestamps. The runner excludes the window's closing endpoint to avoid counting a phase twice.

| Model | channel_1 | output_V | current_A | auxiliary |
| --- | --- | --- | --- | --- |
| 01 | Source voltage (V) | Load voltage | Load current | Conduction state (0 off, 1 or 2 active SCR pair, 3 freewheel) |
| 02 | Phase A source voltage (V) | Load voltage | Load current | Conduction state (0 off, 1 to 6 active SCR pair) |
| 03 | Bridge voltage (V) | Load voltage | Load current | Gating sign (+1 or -1) |
| 04 | Injected bridge current (A) | Load voltage | Resistor current | Capacitor current (A) |
| 05 | PWM command (0 or 1) | Output voltage | Inductor current | Diode conduction (0 or 1) |
| 06 | PWM command (0 or 1) | Output voltage | Input inductor current | Output inductor current (A) |

The model uses 2400 samples per AC fundamental cycle and 400 samples per DC switching cycle. Warm-up uses ten fundamental cycles for rectifiers, six for inverters, and 200/800 switching cycles for the buck-boost/Cuk respectively. The measurements include the last two fundamental cycles or four switching cycles. Interpret the results within the ideal-device model, which omits source impedance, device drops, and commutation transients. The Cuk state update uses continuous conduction and the scanned duty range is chosen to keep both inductor currents positive under the model assumptions.
