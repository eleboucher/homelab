import * as pulumi from "@pulumi/pulumi";

export const requireEnv = (name: string) => {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return pulumi.secret(value);
};
