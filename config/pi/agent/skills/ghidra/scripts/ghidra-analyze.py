#!/usr/bin/env python3
"""Wrapper script for Ghidra headless analysis."""
import argparse
import os
import shlex
import subprocess
import sys


def find_analyze_headless(script_dir):
    find_script = os.path.join(script_dir, "find-ghidra")
    try:
        return subprocess.check_output([sys.executable, find_script], text=True).strip()
    except FileNotFoundError:
        print("Python not found in PATH", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(e.stderr, file=sys.stderr)
        sys.exit(e.returncode)


def main():
    parser = argparse.ArgumentParser(description="Analyze a binary with Ghidra headless")
    parser.add_argument("binary", help="Binary file to analyze")
    parser.add_argument("-o", "--output", default=".", help="Output directory for results")
    parser.add_argument("-s", "--script", action="append", default=[], help="Post-analysis script")
    parser.add_argument("-a", "--script-args", action="append", default=[], help="Arguments for the last specified script")
    parser.add_argument("--script-path", default="", help="Additional script search path")
    parser.add_argument("-p", "--processor", default="", help="Processor/architecture ID")
    parser.add_argument("-c", "--cspec", default="", help="Compiler spec")
    parser.add_argument("--no-analysis", action="store_true", help="Skip auto-analysis")
    parser.add_argument("--timeout", default="", help="Analysis timeout per file in seconds")
    parser.add_argument("--keep-project", action="store_true", help="Keep the Ghidra project after analysis")
    parser.add_argument("--project-dir", default="/tmp", help="Directory for Ghidra project")
    parser.add_argument("--project-name", default="", help="Project name")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    args = parser.parse_args()

    binary = args.binary
    if not os.path.isfile(binary):
        print(f"Error: Binary file not found: {binary}", file=sys.stderr)
        sys.exit(1)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    analyze_headless = find_analyze_headless(script_dir)
    ghidra_home = os.path.dirname(os.path.dirname(analyze_headless))

    output_dir = args.output
    os.makedirs(output_dir, exist_ok=True)

    if not args.project_name:
        base_name = os.path.splitext(os.path.basename(binary))[0]
        args.project_name = f"ghidra_{base_name.replace('.', '_')}_{os.getpid()}"

    builtin_scripts = os.path.join(script_dir, "ghidra_scripts")
    full_script_path = f"{builtin_scripts};{args.script_path}" if args.script_path else builtin_scripts

    cmd = [analyze_headless, args.project_dir, args.project_name, "-import", binary]
    cmd += ["-scriptPath", full_script_path]

    script_arg_map = {}
    for idx, val in enumerate(args.script_args, start=1):
        script_arg_map[idx] = val

    for i, script in enumerate(args.script):
        cmd += ["-postScript", script]
        key = i + 1
        if key in script_arg_map:
            cmd.extend(shlex.split(script_arg_map[key]))

    os.environ["GHIDRA_OUTPUT_DIR"] = output_dir

    if args.processor:
        cmd += ["-processor", args.processor]
    if args.cspec:
        cmd += ["-cspec", args.cspec]
    if args.no_analysis:
        cmd.append("-noanalysis")
    if args.timeout:
        cmd += ["-analysisTimeoutPerFile", args.timeout]
    if not args.keep_project:
        cmd.append("-deleteProject")

    log_file = os.path.join(output_dir, "ghidra_analysis.log")
    cmd += ["-log", log_file]

    if args.verbose:
        print(f"Running: {' '.join(cmd)}")

    output_log = os.path.join(output_dir, "ghidra_output.log")
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    with open(output_log, "w", text=True) as log_file_handle:
        for line in proc.stdout:
            sys.stdout.write(line)
            log_file_handle.write(line)

    exit_code = proc.wait()

    if exit_code == 0:
        print("")
        print(f"Analysis complete. Output files in: {output_dir}")
        for entry in sorted(os.listdir(output_dir)):
            path = os.path.join(output_dir, entry)
            if os.path.isdir(path):
                print(f"  {entry}/")
            else:
                size = os.path.getsize(path)
                print(f"  {entry} ({size} bytes)")
    else:
        print(f"Analysis failed with exit code: {exit_code}", file=sys.stderr)
        print(f"Check log file: {log_file}", file=sys.stderr)

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
