import { Rcon } from "rcon-client";

const MC_SERVER_PRIVATE_DOMAIN_NAME = process.env.MC_SERVER_PRIVATE_DOMAIN_NAME;
const RCON_PORT = process.env.RCON_PORT;

export const handler = async function (event, context) {
  try {
    console.log(event)
    console.log("Running save on Minecraft server...")
    // The function will fail here if the ECS service is already stopped
    const rcon = await Rcon.connect({
      host: MC_SERVER_PRIVATE_DOMAIN_NAME, port: RCON_PORT, password: "minecraft", timeout: 1000
    })
    console.log("Connected to Minecraft server via RCON")
    await rcon.send("broadcast Server is saving the world...")
    console.log(await rcon.send("save-all"))
    const listOutput = await rcon.send("list");
    // There is a cloudwatch log rule that watches for this output
    console.log(listOutput)
    rcon.end();

    const regex = /There are 0/gm;
    const detectNoPlayers = regex.exec(listOutput)
    console.log(listOutput)
    if (detectNoPlayers) {
      return {
        statusCode: 200,
        body: JSON.stringify("No players found on the Minecraft server.")
      }
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