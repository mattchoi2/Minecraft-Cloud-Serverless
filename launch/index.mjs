import { ECSClient, UpdateServiceCommand } from "@aws-sdk/client-ecs";
import { gunzipSync } from 'zlib';

const ecs = new ECSClient();

const ECS_CLUSTER_NAME = process.env.ECS_CLUSTER_NAME;
const MC_SERVER_DOMAIN_NAME = process.env.MC_SERVER_DOMAIN_NAME;
const MC_ECS_SERVICE_NAME = process.env.MC_ECS_SERVICE_NAME;

async function updateMinecraftServerReplicas(replicaCount) {
  const params = new UpdateServiceCommand({
    service: MC_ECS_SERVICE_NAME,
    desiredCount: replicaCount,
    cluster: ECS_CLUSTER_NAME
  });
  await ecs.send(params);
}

export const handler = async function (event, context) {
  try {
    console.log(event)
    const payload = Buffer.from(event.awslogs.data, 'base64');
    const logevents = JSON.parse(gunzipSync(payload).toString()).logEvents;
    const log = logevents[0];
    const msg = log.message;
    if (msg.includes(MC_SERVER_DOMAIN_NAME)) {
      console.log("Looks like someone wants to play on the server... Starting now");
      await updateMinecraftServerReplicas(1);
    } else if (msg.includes("There are 0 of a max of")) {
      console.log("No users detected on the Minecraft server!  Shutting down...")
      await updateMinecraftServerReplicas(0);
      console.log("The Minecraft server is now off!  Desired tasks set to 0.")
    }
  } catch (err) {
    console.log(err);
    return {
      statusCode: 500,
      body: JSON.stringify("Failure!")
    }
  }
  return {
    statusCode: 200,
    body: JSON.stringify("Success!")
  }
}