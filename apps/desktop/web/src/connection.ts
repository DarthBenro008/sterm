import { invoke } from "@tauri-apps/api/core";

export interface ConnectionInput {
  host: string;
  username: string;
  password: string;
  port: number;
}

export type ConnectionStepStatus = "pending" | "running" | "complete" | "failed" | "skipped";

export interface ConnectionStep {
  id: string;
  label: string;
  status: ConnectionStepStatus;
  detail: string;
}

export interface ConnectionResult {
  status: "connected" | "preview";
  host: string;
  username: string;
  port: number;
  remoteHome: string;
  installDir: string;
  socketPath: string;
  agentVersion: string;
  protocolVersion: number;
  steps: ConnectionStep[];
  terminalBanner: string;
}

export function normalizeConnectionInput(input: ConnectionInput): ConnectionInput {
  return {
    host: input.host.trim(),
    username: input.username.trim(),
    password: input.password,
    port: Number.isInteger(input.port) && input.port > 0 ? input.port : 22,
  };
}

export function validateConnectionInput(input: ConnectionInput): string | null {
  const normalized = normalizeConnectionInput(input);
  if (!normalized.host) return "Server IP or hostname is required.";
  if (!normalized.username) return "Username is required.";
  if (!normalized.password) return "Password is required for password bootstrap.";
  if (normalized.port < 1 || normalized.port > 65535) return "SSH port must be between 1 and 65535.";
  return null;
}

export async function connectRemoteWorkspace(input: ConnectionInput): Promise<ConnectionResult> {
  const normalized = normalizeConnectionInput(input);
  const validationError = validateConnectionInput(normalized);
  if (validationError) throw new Error(validationError);

  const response = await invoke<string>("connect_remote_workspace_json", {
    payload: JSON.stringify(normalized),
  });
  return parseConnectionResult(response);
}

export function parseConnectionResult(response: string): ConnectionResult {
  const parsed = JSON.parse(response) as ConnectionResult;
  if (!parsed || typeof parsed !== "object") {
    throw new Error("Connection response was empty.");
  }
  if (!parsed.host || !parsed.username || !Array.isArray(parsed.steps)) {
    throw new Error("Connection response did not include the expected workspace fields.");
  }
  return parsed;
}
