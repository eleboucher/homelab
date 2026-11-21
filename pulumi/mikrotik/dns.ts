import * as routeros from "@pulumi/routeros";

new routeros.IpDns("server", {
  allowRemoteRequests: true,
  servers: ["192.168.1.1"],
  cacheSize: 20480,
  cacheMaxTtl: "1d",
  maxConcurrentQueries: 500,
  maxConcurrentTcpSessions: 100,
  queryServerTimeout: "8s",
});
