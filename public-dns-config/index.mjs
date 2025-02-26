import { EC2Client, DescribeNetworkInterfacesCommand } from "@aws-sdk/client-ec2";
import { Route53Client, ChangeResourceRecordSetsCommand } from "@aws-sdk/client-route-53";
import { ECSClient, DescribeTasksCommand } from "@aws-sdk/client-ecs";

const HOSTED_ZONE_ID = process.env.HOSTED_ZONE_ID;
const ECS_CLUSTER_NAME = process.env.ECS_CLUSTER_NAME;
const MC_SERVER_DOMAIN_NAME = process.env.MC_SERVER_DOMAIN_NAME;

const ec2 = new EC2Client();
const ecs = new ECSClient();
const route53 = new Route53Client();

async function updateDNSRecord(taskArn) {
  let params = new DescribeTasksCommand({
    tasks: [taskArn],
    cluster: ECS_CLUSTER_NAME
  });
  const results = await ecs.send(params);
  const networkAttachmentDetails = results.tasks[0].attachments[0].details
  const enis = networkAttachmentDetails.filter(function (item) {
    return item.name === "networkInterfaceId";
  })
  const eniId = enis[0].value;
  console.log(eniId)

  params = new DescribeNetworkInterfacesCommand({ NetworkInterfaceIds: [eniId] });
  const interfaceResults = await ec2.send(params);
  console.log(interfaceResults);
  const publicIp = interfaceResults.NetworkInterfaces[0].Association.PublicIp;
  console.log(publicIp)

  params = new ChangeResourceRecordSetsCommand({
    ChangeBatch: {
      Changes: [
        {
          Action: "UPSERT",
          ResourceRecordSet: {
            Name: MC_SERVER_DOMAIN_NAME,
            Type: "A",
            TTL: 1,
            ResourceRecords: [{ Value: publicIp }]
          }
        }
      ]
    },
    HostedZoneId: HOSTED_ZONE_ID
  });
  const updateResults = await route53.send(params);
  console.log(updateResults)
}

export const handler = async function (event, context) {
  try {
    console.log(event)
    console.log("New ECS service fargate container has entered ready status!  Running network configurations...")
    await updateDNSRecord(event.detail["taskArn"])
  } catch (err) {
    console.log(err);
    return {
      statusCode: 500,
      body: JSON.stringify("Failure!")
    }
  }
}