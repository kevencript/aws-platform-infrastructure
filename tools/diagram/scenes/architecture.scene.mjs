// Architecture diagram: production topology in us-east-2.
//
// This file is the source of truth for the picture. It is plain data: it
// places containers, service boxes and arrows on a grid derived from the
// layout constants below, and the build (npm run build) turns the result into
// docs/diagrams/architecture.excalidraw and diagram.png.
//
// Reading order: layout constants, containers, nodes, arrows, legend.
// To move something, change a constant; positions are derived, not typed in.
// A size that is typed in says what it follows: a rule, or the text it has to
// hold. Node.js cannot measure text, so such a text is named, and the build
// fails if it stops fitting.
//
// Names: *_BOX_Y is the top of a box, *_ROW_Y the top of a row in the node
// group, FLOW_n_Y the y of arrow n.
import { LEGEND_SAMPLE_ROOM, SIZE, arrow, chip, container, legend, node, text, withTag } from "./lib/skeleton.mjs";

// ===================================================================== layout
//
// The origin is the top-left corner of the outermost container, the AWS
// account, which this file calls the cloud. External actors sit above it, at
// negative y; the legend and the note sit below it.
//
//   x:  | left column | gutter | VPC (label zone + service zone) | gutter | right column |
//   y:  VPC header, public tier, gutter, app tier, gutter, data tier
//
// Inside the VPC every tier is a horizontal band. The left part of a band
// (the label zone) holds its title and subnet chips; services live in the
// rest. Gutters are kept free of boxes so arrow labels have clear space.

const PAD = 16; // between a container and the container inside it
const TITLE_ROW = 40; // room for a one-line container title
const INSET = 12; // between a group border and the boxes in it
const ARROWHEAD = 16; // length of an arrowhead, rounded up
const ARROWHEAD_ROOM = INSET + ARROWHEAD; // border to boxes on a side arrows enter by: the whole arrowhead lies inside the group
const GROUP_TITLE = 36; // room for a one-line group title
const LABEL_MARGIN = 8; // least distance between a free label and a border it must not touch
const SINGLE_LINE_BOX_H = 44; // a box with a title only, unless it takes its height from a taller box beside it
const TWO_LINE_BOX_H = 66; // a box with a title and one line under it
const THREE_LINE_BOX_H = 84; // a box with a title and two lines under it
// A title-only box around one of the two longest titles, "DynamoDB lock table"
// (188 wide) and "S3 gateway endpoint" (183): the title keeps a corner radius
// and a little more of air on each side.
const LONG_TITLE_BOX_W = 216;

// ---- columns
const LEFT = { x: 2 * PAD, w: 280 }; // its boxes just fit the second line of Route 53
const GUTTER_LEFT = 164; // association labels, then the lane the association lines turn in
const VPC_X = LEFT.x + LEFT.w + GUTTER_LEFT;
const BAND_INSET = 16; // VPC border to tier band, band border to its content
const LABEL_ZONE = 236; // a tier's title, route and subnet chips, with a gap before its services
const DATA_BOX = { w: 232, gap: 16 }; // the three data stores fill the service zone; w just fits the line of the migration job, whose box is as wide
const SERVICE_ZONE = 3 * DATA_BOX.w + 2 * DATA_BOX.gap;
const BAND = { x: VPC_X + BAND_INSET, w: LABEL_ZONE + SERVICE_ZONE + BAND_INSET };
const VPC_W = BAND.w + 2 * BAND_INSET;
const VPC_RIGHT = VPC_X + VPC_W;
const GUTTER_RIGHT = 306; // the labels of flows 7 to 10 above their lines; flow 7 has the longest
const RIGHT = { x: VPC_RIGHT + GUTTER_RIGHT, w: 346 }; // its boxes just fit the second line of Secrets Manager
const SERVICE_ZONE_X = BAND.x + LABEL_ZONE; // left edge of the service zone
const LEFT_BOX = { x: LEFT.x + INSET, w: LEFT.w - 2 * INSET };
const RIGHT_BOX = { x: RIGHT.x + ARROWHEAD_ROOM, w: RIGHT.w - ARROWHEAD_ROOM - INSET };

// ---- left column: the three edge services, stacked beside the public tier
const EDGE_BOX = { h: TWO_LINE_BOX_H, gap: INSET }; // as far from each other as from the group border
const EDGE_PITCH = EDGE_BOX.h + EDGE_BOX.gap;

// ---- rows
const TOP = 2 * TITLE_ROW; // first y inside the region
const VPC_HEADER = 72; // VPC title and the internet gateway
// The public tier is laid out against the edge group beside it. A box in a
// tier is as tall as an edge box plus the gaps around it, so the load
// balancer starts and ends level with the edge boxes above and below the one
// it faces. The tier is as tall as the three edge boxes, the gaps between
// them and an inset above and below, so it ends level with the bottom of the
// edge group.
const TIER_BOX_H = EDGE_BOX.h + 2 * EDGE_BOX.gap;
const PUBLIC = { y: TOP + VPC_HEADER, h: 3 * EDGE_BOX.h + 2 * EDGE_BOX.gap + 2 * INSET };
const GUTTER_PUBLIC_APP = 100; // one row of arrow labels, and the arrowheads of flows 11 and 6 under the public tier
const NODE_GROUP_HEADER = 60; // node group title, two lines
// The node group has three rows. The right end of each holds a workload that
// calls one regional service, with a level arrow from the middle of its right
// edge: the cluster add-ons, under them the database migration job, and the
// API pods, which take the whole third row.
const ADDON_ROW_H = THREE_LINE_BOX_H; // the add-ons
const MIGRATION_ROW_H = TWO_LINE_BOX_H; // the migration job
const ROW_GAP = INSET; // between two rows: as far apart as the edge boxes
// The pods are as tall as the add-ons. That puts their middle as far below
// the middle of the migration job as that one is below the middle of the
// add-ons, so the three calls leave the group at one pitch.
const PODS_H = ADDON_ROW_H;
const NODE_GROUP_H = NODE_GROUP_HEADER + ADDON_ROW_H + ROW_GAP + MIGRATION_ROW_H + ROW_GAP + PODS_H + BAND_INSET;
const APP = { y: PUBLIC.y + PUBLIC.h + GUTTER_PUBLIC_APP, h: NODE_GROUP_H + 2 * BAND_INSET };
const GUTTER_APP_DATA = 84; // one row of arrow labels
// Subnet chips: one per Availability Zone, stacked in the bottom-left corner
// of every tier.
const CHIP = { w: 192, h: 24, gap: 5, bottom: 10 }; // w just fits the widest chip, "us-east-2b  10.30.32.0/20"
const CHIP_STACK_H = 3 * CHIP.h + 2 * CHIP.gap;
// The data tier is as low as its label zone allows: the title and the route
// line, a clear gap, the chip stack and the space under it.
const TIER_TITLE_ROWS = 50; // a tier's title and route line, from the band's top border
const TITLE_TO_CHIPS = 28; // least gap between a tier's route line and its first chip
const DATA = { y: APP.y + APP.h + GUTTER_APP_DATA, h: TIER_TITLE_ROWS + TITLE_TO_CHIPS + CHIP_STACK_H + CHIP.bottom };
const VPC_BOTTOM = DATA.y + DATA.h + BAND_INSET;

// ---- right column: the regional services line up with what calls them.
// Their pitch is the pitch of the calls that leave the node group, from the
// middle of one row to the middle of the next, so each of the three services
// called from there is centred on its arrow.
const REGIONAL_PITCH = ADDON_ROW_H / 2 + ROW_GAP + MIGRATION_ROW_H / 2;
const REGIONAL_BOX = { h: TWO_LINE_BOX_H, gap: REGIONAL_PITCH - TWO_LINE_BOX_H }; // gap: what that pitch leaves between two boxes

// ---- outer frame
// The region leaves one PAD around the three columns, the cloud one more
// around the region.
const REGION_RIGHT = RIGHT.x + RIGHT.w + PAD;
const REGION_BOTTOM = VPC_BOTTOM + PAD;
const REGION = { x: PAD, y: TITLE_ROW, w: REGION_RIGHT - PAD, h: REGION_BOTTOM - TITLE_ROW };
const CLOUD = { x: 0, y: 0, w: REGION_RIGHT + PAD, h: REGION_BOTTOM + PAD };
const ACTOR = { h: TWO_LINE_BOX_H, gap: 64 }; // external actors, and their distance from the cloud: room for an arrow label with air around it
const ACTOR_BOX_Y = -ACTOR.gap - ACTOR.h;
const ACTOR_LABEL_Y = -ACTOR.gap / 2; // arrow labels between an actor and the cloud

// ---- shared positions inside the tiers
const NODE_GROUP = { x: SERVICE_ZONE_X, y: APP.y + BAND_INSET, w: SERVICE_ZONE, h: NODE_GROUP_H };
const ADDON_ROW_Y = NODE_GROUP.y + NODE_GROUP_HEADER;
const MIGRATION_ROW_Y = ADDON_ROW_Y + ADDON_ROW_H + ROW_GAP;
const PODS = { x: NODE_GROUP.x + BAND_INSET, y: MIGRATION_ROW_Y + MIGRATION_ROW_H + ROW_GAP, w: NODE_GROUP.w - 2 * BAND_INSET, h: PODS_H };
const PUBLIC_BOX_Y = PUBLIC.y + (PUBLIC.h - TIER_BOX_H) / 2;
const PUBLIC_MID_Y = PUBLIC.y + PUBLIC.h / 2;
const DATA_BOX_Y = DATA.y + (DATA.h - TIER_BOX_H) / 2;
const dataBoxX = (i) => SERVICE_ZONE_X + i * (DATA_BOX.w + DATA_BOX.gap);

// Three vertical lanes, one over the middle of each data store. Every arrow
// that runs between two tiers uses one of them, so arrows in the upper gutter
// line up with the arrows in the lower one.
const LANE = [0, 1, 2].map((i) => dataBoxX(i) + DATA_BOX.w / 2);
const ALB_MID_X = (LANE[0] + LANE[1]) / 2; // the load balancer spans lanes 0 and 1
// It reaches the same distance beyond both lanes: far enough for arrows 11
// and 2 to meet its bottom edge well inside the corners, and for its second
// line, the longest in the public tier (314 wide), to fit with air to spare.
const ALB_OVERHANG = 66;
const ALB = { w: LANE[1] - LANE[0] + 2 * ALB_OVERHANG };
const LBC = { x: PODS.x, w: 2 * (LANE[0] - PODS.x), h: MIGRATION_ROW_Y + MIGRATION_ROW_H - ADDON_ROW_Y }; // AWS Load Balancer Controller, centred on lane 0, from the top of the first row to the bottom of the second
const NAT = { w: LBC.w }; // centred on lane 2 and as wide as the controller on lane 0, so it ends level with the pod box
const IMAGE_PULL_INSET = 24; // from the node group's right corner; keeps image pulls clear of the egress lane
const IMAGE_PULL_X = NODE_GROUP.x + NODE_GROUP.w - IMAGE_PULL_INSET;

// Where arrow labels sit: half-way down each gutter, and at one x on the right.
const LABEL_Y_PUBLIC_APP = PUBLIC.y + PUBLIC.h + GUTTER_PUBLIC_APP / 2;
const LABEL_Y_APP_DATA = APP.y + APP.h + GUTTER_APP_DATA / 2;
const LABEL_X_RIGHT = VPC_RIGHT + PAD;

// ---- right column, continued: arrows 10, 8 and 7 leave the middle of the
// add-ons, the migration job and the pods. The service each of them calls is
// centred on its arrow, and the other three are stacked around those.
const FLOW_10_Y = ADDON_ROW_Y + ADDON_ROW_H / 2;
const FLOW_8_Y = MIGRATION_ROW_Y + MIGRATION_ROW_H / 2;
const FLOW_7_Y = PODS.y + PODS.h / 2;
const CLOUDWATCH_BOX_Y = FLOW_10_Y - REGIONAL_BOX.h / 2;
const SECRETS_BOX_Y = FLOW_8_Y - REGIONAL_BOX.h / 2;
const IAM_BOX_Y = FLOW_7_Y - REGIONAL_BOX.h / 2;
const KMS_BOX_Y = IAM_BOX_Y + REGIONAL_PITCH;
const SHORT_ARROW = 58; // a box-to-box gap long enough for a dotted arrow to show four dots
const TOPIC_BOX_Y = CLOUDWATCH_BOX_Y - SHORT_ARROW - SINGLE_LINE_BOX_H;
const ECR_BOX_Y = TOPIC_BOX_Y - REGIONAL_BOX.gap - REGIONAL_BOX.h;

// ---- bootstrap stack (Terraform state and CI identity): above the regional
// services. The group is wider than the column, to the left, so that its two
// state boxes are the same size with a one-line title each.
const STATE_BOX = { w: LONG_TITLE_BOX_W, h: TWO_LINE_BOX_H }; // both boxes as wide as the lock table's title needs, as high as the state bucket's two lines
const STATE_LINK = SHORT_ARROW; // provider to state boxes: the gap a short arrow gets, which leaves each association line room for the label beside it
const BOOTSTRAP_INNER_W = 2 * STATE_BOX.w + INSET;
const BOOTSTRAP_W = ARROWHEAD_ROOM + BOOTSTRAP_INNER_W + INSET;
const BOOTSTRAP = { x: RIGHT.x + RIGHT.w - BOOTSTRAP_W, y: TOP, w: BOOTSTRAP_W, h: GROUP_TITLE + THREE_LINE_BOX_H + STATE_LINK + STATE_BOX.h + INSET };
const BOOTSTRAP_BOX_X = BOOTSTRAP.x + ARROWHEAD_ROOM;
const CI_X = (VPC_RIGHT + BOOTSTRAP.x) / 2; // lane the CI arrow comes down in

// ================================================================= containers

const cloud = container({ id: "cloud", ...CLOUD, title: "AWS account: prod", kind: "cloud", fontSize: SIZE.containerTitle });
const region = container({ id: "region", ...REGION, title: "Region us-east-2", kind: "region", fontSize: SIZE.containerTitle });
const vpc = container({
  id: "vpc", x: VPC_X, y: TOP, w: VPC_W, h: VPC_BOTTOM - TOP,
  title: "VPC  10.30.0.0/16", subtitle: "dev: 10.20.0.0/16", kind: "vpc", fontSize: SIZE.containerTitle,
});

// ---- subnet tiers: one band each, with a chip per Availability Zone
// The title sits in the top-left corner of the band and the chips in the
// bottom-left, which leaves the middle of the label zone open for lines to
// cross (the edge associations and the control-plane link both do).
function tier({ id, kind, y, h, title, route, cidrs }) {
  const band = container({ id, x: BAND.x, y, w: BAND.w, h, title, subtitle: route, kind, inset: INSET });
  const chipsTop = y + h - CHIP.bottom - CHIP_STACK_H;
  const chips = cidrs.map((cidr, i) => {
    const az = `us-east-2${"abc"[i]}`;
    return chip({ id: `${id}-${az}`, x: BAND.x + INSET, y: chipsTop + i * (CHIP.h + CHIP.gap), w: CHIP.w, h: CHIP.h, label: `${az}  ${cidr}`, kind });
  });
  return { band, chips };
}

const publicTier = tier({
  id: "subnets-public", kind: "publicSubnet", ...PUBLIC,
  title: "Public subnets", route: "route 0.0.0.0/0 → internet gateway",
  cidrs: ["10.30.0.0/24", "10.30.1.0/24", "10.30.2.0/24"],
});
const appTier = tier({
  id: "subnets-app", kind: "appSubnet", ...APP,
  title: "Private app subnets", route: "route 0.0.0.0/0 → NAT gateway",
  cidrs: ["10.30.16.0/20", "10.30.32.0/20", "10.30.48.0/20"],
});
const dataTier = tier({
  id: "subnets-data", kind: "dataSubnet", ...DATA,
  title: "Private data subnets", route: "no default route",
  cidrs: ["10.30.8.0/24", "10.30.9.0/24", "10.30.10.0/24"],
});

// ---- EKS node group, inside the app tier. Title on the right so the arrows
// that cross its top edge on the left have nothing to run over.
const nodeGroup = withTag(
  container({
    id: "node-group", ...NODE_GROUP,
    title: "EKS managed node group", subtitle: "AL2023  ·  IMDSv2, hop limit 1", kind: "nodeGroup", titleAlign: "end",
  }),
  "SG: node",
  { align: "start" },
);

// ---- logical groups outside the VPC
const ACM_BOX_Y = PUBLIC_MID_Y - EDGE_BOX.h / 2; // level with the load balancer
const edge = container({
  id: "edge", x: LEFT.x, y: ACM_BOX_Y - EDGE_PITCH - GROUP_TITLE, w: LEFT.w, h: GROUP_TITLE + 3 * EDGE_PITCH - EDGE_BOX.gap + INSET,
  title: "Edge",
});

const bootstrap = container({ id: "bootstrap", ...BOOTSTRAP, title: "Bootstrap stack  (once per account)" });

const regional = container({
  id: "regional", x: RIGHT.x, y: ECR_BOX_Y - GROUP_TITLE, w: RIGHT.w, h: GROUP_TITLE + KMS_BOX_Y + REGIONAL_BOX.h + INSET - ECR_BOX_Y,
  title: "Regional AWS services",
});

// ====================================================================== nodes

// ---- external actors, each centred on the arrow that leaves it
const CLIENTS_W = 170; // its title, "Internet clients" (128 wide), with about 20 of air each side
const GITHUB_ACTIONS_W = 270; // just fits its second line
const clients = node({ id: "clients", x: ALB_MID_X - CLIENTS_W / 2, y: ACTOR_BOX_Y, w: CLIENTS_W, h: ACTOR.h, title: "Internet clients" });
const githubActions = node({
  id: "github-actions", x: CI_X - GITHUB_ACTIONS_W / 2, y: ACTOR_BOX_Y, w: GITHUB_ACTIONS_W, h: ACTOR.h,
  title: "GitHub Actions", lines: ["plan on pull request · apply on merge"],
});

// ---- edge. The hosted zone is created by the bootstrap stack; it is drawn
// here because the edge module creates the records in it.
const edgeBox = (i, props) => node({ ...LEFT_BOX, y: ACM_BOX_Y + (i - 1) * EDGE_PITCH, h: EDGE_BOX.h, ...props });
const route53 = edgeBox(0, { id: "route53", title: "Route 53 hosted zone", lines: ["alias + certificate validation records"], category: "networking" });
const acm = edgeBox(1, { id: "acm", title: "ACM certificate", lines: ["DNS validated"], category: "security" });
const waf = edgeBox(2, { id: "waf", title: "WAFv2 web ACL", lines: ["rate limit + AWS managed rules"], category: "security" });

// ---- VPC: gateways and the public tier
// The internet gateway sits in the VPC header, just inside the top edge. It
// reaches from the load balancer's centre line to lane 1 and beyond each:
// inbound traffic passes behind its left part, and outbound traffic leaves
// from its right part, up lane 1, clear of the "Internet clients" box. Each
// of the two lines meets the box three arrowhead lengths in from its end, so
// the box reads as something the traffic goes through, not a cap on a line.
const IGW_OVERHANG = 3 * ARROWHEAD;
const EGRESS_X = LANE[1];
const IGW = { x: ALB_MID_X - IGW_OVERHANG, y: TOP + (VPC_HEADER - SINGLE_LINE_BOX_H) / 2, w: EGRESS_X - ALB_MID_X + 2 * IGW_OVERHANG, h: SINGLE_LINE_BOX_H };
const igw = node({ id: "igw", ...IGW, title: "Internet gateway", category: "networking" });
const alb = node({
  id: "alb", x: ALB_MID_X - ALB.w / 2, y: PUBLIC_BOX_Y, w: ALB.w, h: TIER_BOX_H,
  title: "Application Load Balancer", lines: ["internet-facing · HTTPS 443 · HTTP 80 → 301"], category: "networking", tag: "SG: alb",
});
const nat = node({
  id: "nat", x: LANE[2] - NAT.w / 2, y: PUBLIC_BOX_Y, w: NAT.w, h: TIER_BOX_H,
  title: "NAT gateways", lines: ["one per AZ  (dev: single)"], category: "networking",
});

// ---- VPC: workloads on the node group
// The add-ons and the migration job take the right end of the first two rows,
// one under the other and as wide as the data store below them. The
// controller, on the left, starts level with the first and ends level with
// the second, so both sides of lane 1 are filled to the same height.
const CALLER_STACK = { x: PODS.x + PODS.w - DATA_BOX.w, w: DATA_BOX.w };
const lbc = node({
  id: "lb-controller", x: LBC.x, y: ADDON_ROW_Y, w: LBC.w, h: LBC.h,
  title: "AWS Load Balancer\nController", lines: ["TargetGroupBinding"], category: "compute",
});
const addons = node({
  id: "addons", ...CALLER_STACK, y: ADDON_ROW_Y, h: ADDON_ROW_H,
  title: "Cluster add-ons", lines: ["vpc-cni · kube-proxy · coredns", "CloudWatch agent"], category: "compute",
});
// The migration job runs as a pod on the same nodes as the API, under a
// service account of its own. It is the only workload that reads the
// database's master secret; the API signs in with IAM database authentication.
const migrationJob = node({
  id: "db-migration-job", ...CALLER_STACK, y: MIGRATION_ROW_Y, h: MIGRATION_ROW_H,
  title: "DB migration job", lines: ["ServiceAccount api/db-migrator"], category: "compute",
});
const pods = node({
  id: "api-pods", ...PODS,
  title: "API pods", lines: ["Node.js :3000 · ServiceAccount api/api"], category: "compute",
});

// ---- VPC: data tier. Every box has the same two lines: the port and the key
// facts of that store, IAM authentication among them, then encryption at
// rest, in the same words on all three. Under a title, two lines only leave
// the title clear of the tag on the box's top edge at the dense size.
const ENCRYPTED_AT_REST = "encrypted at rest · KMS";
const dataBox = (i, { facts, ...props }) =>
  node({ x: dataBoxX(i), y: DATA_BOX_Y, w: DATA_BOX.w, h: TIER_BOX_H, lines: [facts, ENCRYPTED_AT_REST], lineSize: SIZE.boxLineDense, ...props });
const rds = dataBox(0, { id: "rds", title: "RDS PostgreSQL", facts: ":5432 · Multi-AZ · IAM auth", category: "database", tag: "SG: rds" });
const redis = dataBox(1, { id: "redis", title: "ElastiCache Redis", facts: ":6379 · TLS required · IAM auth", category: "database", tag: "SG: redis" });
const msk = dataBox(2, { id: "msk", title: "Amazon MSK (Kafka)", facts: ":9098 · SASL/IAM · 3 brokers", category: "analytics", tag: "SG: msk" });

// ---- S3 gateway endpoint: on the VPC's right edge at the height of the app
// tier, whose route tables point at it. It overlaps the VPC border just enough
// to sit on it without reaching the tier band, and `drop` puts it in the free
// slot between the image-pull arrow above and the telemetry label below.
const S3_ENDPOINT = { w: LONG_TITLE_BOX_W, h: SINGLE_LINE_BOX_H, overlap: 8, drop: 8 };
const s3Endpoint = node({
  id: "s3-endpoint", x: VPC_RIGHT - S3_ENDPOINT.overlap, y: NODE_GROUP.y + S3_ENDPOINT.drop, w: S3_ENDPOINT.w, h: S3_ENDPOINT.h,
  title: "S3 gateway endpoint", category: "networking",
});

// ---- EKS control plane: left of the app tier, centred on arrow 13, which
// runs level with the gap above the pods so that it points at the node group,
// not at a box in it
const FLOW_13_Y = PODS.y - ROW_GAP / 2;
const controlPlane = node({
  id: "eks-control-plane", ...LEFT_BOX, y: FLOW_13_Y - THREE_LINE_BOX_H / 2, h: THREE_LINE_BOX_H,
  title: "EKS control plane", lines: ["AWS managed", "private API endpoint · OIDC issuer"], category: "compute",
});

// ---- regional services
const regionalBox = (y, props) => node({ ...RIGHT_BOX, y, h: REGIONAL_BOX.h, ...props });
const ecr = regionalBox(ECR_BOX_Y, { id: "ecr", title: "Amazon ECR", lines: ["immutable tags · lifecycle policy"], category: "compute" });
const sns = regionalBox(TOPIC_BOX_Y, { id: "sns", h: SINGLE_LINE_BOX_H, title: "SNS alarm topic", category: "management" });
const cloudwatch = regionalBox(CLOUDWATCH_BOX_Y, { id: "cloudwatch", title: "CloudWatch", lines: ["logs · metrics · alarms"], category: "management" });
const secrets = regionalBox(SECRETS_BOX_Y, { id: "secrets-manager", title: "Secrets Manager", lines: ["RDS-managed master secret, auto-rotated"], category: "security" });
const iam = regionalBox(IAM_BOX_Y, { id: "iam", title: "IAM · STS", lines: ["EKS OIDC provider · IRSA roles"], category: "security" });
const kms = regionalBox(KMS_BOX_Y, { id: "kms", title: "KMS", lines: ["customer managed keys"], category: "security" });

// ---- bootstrap stack: Terraform state and CI identity. The box shows the
// two roles of this account; the dev account has the same pair, with an apply
// role for the GitHub environment dev.
const OIDC_BOX_Y = BOOTSTRAP.y + GROUP_TITLE;
const STATE_BOX_Y = OIDC_BOX_Y + THREE_LINE_BOX_H + STATE_LINK;
const githubOidc = node({
  id: "github-oidc", x: BOOTSTRAP_BOX_X, y: OIDC_BOX_Y, w: BOOTSTRAP_INNER_W, h: THREE_LINE_BOX_H,
  title: "GitHub OIDC provider", lines: ["plan role: read-only, no writes", "apply role: GitHub environment prod"], category: "security",
});
const stateBucket = node({
  id: "state-bucket", x: BOOTSTRAP_BOX_X, y: STATE_BOX_Y, w: STATE_BOX.w, h: STATE_BOX.h,
  title: "S3 state bucket", lines: ["versioned · SSE-KMS"], category: "storage",
});
const lockTable = node({
  id: "lock-table", x: BOOTSTRAP_BOX_X + STATE_BOX.w + INSET, y: STATE_BOX_Y, w: STATE_BOX.w, h: STATE_BOX.h,
  title: "DynamoDB lock table", category: "database",
});

// ===================================================================== arrows
//
// Numbered arrows are traffic and point from the side that opens the
// connection. Nothing starts in the data tier.
//
// Labels never interrupt a dashed or dotted line. They sit beside a vertical
// arrow (a numbered label on its left, an unnumbered caption on its right),
// or above a horizontal one starting at a shared x. Only the thin solid
// association lines that leave the edge group carry their label on the line.

// ---- 1: public entry, drawn before the internet gateway so that it passes behind it
const publicEntry = arrow({
  id: "flow-01-https", flow: "public", from: clients, to: alb, fromSide: "bottom", toSide: "top",
  number: 1, label: "HTTPS 443", labelAt: ACTOR_LABEL_Y, labelSide: "left",
});

// ---- 2 to 5: inside the VPC, one pair of security group rules each: egress
// on the caller, ingress on the target
const internal = [
  arrow({
    id: "flow-02-targets", flow: "internal", from: alb, to: pods, fromSide: "bottom", toSide: "top", fromAt: LANE[1], toAt: LANE[1],
    number: 2, label: "HTTP 3000 · target type ip", labelAt: LABEL_Y_PUBLIC_APP, labelSide: "left",
  }),
  ...[
    { id: "flow-03-postgres", to: rds, number: 3, label: "PostgreSQL 5432 · TLS" },
    { id: "flow-04-redis", to: redis, number: 4, label: "Redis 6379 · TLS" },
    { id: "flow-05-kafka", to: msk, number: 5, label: "Kafka 9098 · SASL/IAM" },
  ].map((flow, i) =>
    arrow({ ...flow, flow: "internal", from: pods, fromSide: "bottom", toSide: "top", fromAt: LANE[i], toAt: LANE[i], labelAt: LABEL_Y_APP_DATA, labelSide: "left" }),
  ),
];

// ---- 6: the only way out, node group -> NAT -> internet gateway -> internet.
// The last leg ends in open space above the cloud, on the row of the labels
// of the arrows that come down from the actors; a caption beside its
// arrowhead says where it goes.
const egress = [
  arrow({
    id: "flow-06-egress", flow: "egress", from: nodeGroup, to: nat, fromSide: "top", toSide: "bottom", fromAt: LANE[2], toAt: LANE[2],
    number: 6, label: "egress only · HTTPS 443", labelAt: LABEL_Y_PUBLIC_APP, labelSide: "left",
  }),
  arrow({ id: "flow-06-nat-to-igw", flow: "egress", from: nat, to: igw, fromSide: "top", toSide: "right", route: "elbow" }),
  arrow({
    id: "flow-06-igw-to-internet", flow: "egress", from: igw, to: { x: EGRESS_X, y: ACTOR_LABEL_Y }, fromSide: "top", fromAt: EGRESS_X,
    label: "internet", labelAt: ACTOR_LABEL_Y, labelSide: "right",
  }),
];

// ---- 13: control plane <-> nodes, the only two-way arrow. Its label starts
// under the app tier's title, in the open middle of the label zone.
const controlLink = arrow({
  id: "flow-13-control-plane", flow: "control", from: controlPlane, to: nodeGroup, fromSide: "right", toSide: "left", fromAt: FLOW_13_Y, toAt: FLOW_13_Y,
  number: 13, label: "API 443 · kubelet 10250", labelAt: BAND.x + INSET, labelSide: "above",
});

// ---- 7 to 12: AWS APIs, identity and telemetry. 7, 8 and 10 are level: each
// leaves the middle of its workload and meets the middle of its service. The
// API pods hold no secret: 8, the only read of the master secret, starts at
// the migration job.
const toRegionalService = (props) =>
  arrow({ flow: "api", fromSide: "right", toSide: "left", labelAt: LABEL_X_RIGHT, labelSide: "above", labelEndsBefore: RIGHT.x - LABEL_MARGIN, ...props });
const awsApi = [
  toRegionalService({ id: "flow-07-irsa", from: pods, to: iam, fromAt: FLOW_7_Y, toAt: FLOW_7_Y, number: 7, label: "IRSA · AssumeRoleWithWebIdentity" }),
  toRegionalService({ id: "flow-08-secret", from: migrationJob, to: secrets, fromAt: FLOW_8_Y, toAt: FLOW_8_Y, number: 8, label: "GetSecretValue · migration role" }),
  toRegionalService({
    id: "flow-09-image-pull", from: nodeGroup, to: ecr, fromSide: "top", fromAt: IMAGE_PULL_X, route: "elbow",
    number: 9, label: "image pull", labelSegment: 1,
  }),
  toRegionalService({ id: "flow-10-telemetry", from: addons, to: cloudwatch, fromAt: FLOW_10_Y, toAt: FLOW_10_Y, number: 10, label: "metrics and logs" }),
  arrow({ id: "flow-10-alarm", flow: "api", from: cloudwatch, to: sns, fromSide: "top", toSide: "bottom", label: "alarm", labelSide: "right" }),
  arrow({
    id: "flow-11-register", flow: "api", from: lbc, to: alb, fromSide: "top", toSide: "bottom", fromAt: LANE[0], toAt: LANE[0],
    number: 11, label: "registers pod IPs in target group", labelAt: LABEL_Y_PUBLIC_APP, labelSide: "left",
  }),
  arrow({
    id: "flow-12-ci-identity", flow: "api", from: githubActions, to: githubOidc, fromSide: "bottom", toSide: "left", route: "elbow",
    number: 12, label: "OIDC token → short-lived role", labelSegment: 0, labelAt: ACTOR_LABEL_Y, labelSide: "left",
  }),
];

// ---- associations: not traffic, no arrowhead.
// An arrow stops a little short of a box so that its head stays clear of the
// border. A line without a head stops half as far away: it has to read as
// joined to the two boxes it associates.
const ASSOCIATION_END_GAP = 2;
// Edge services to the load balancer. Each line ends at its own point on the
// load balancer's left edge, so the three never touch. The outer two turn in
// a lane well clear of the VPC border; each label sits on the stretch between
// the edge group and that lane.
const ASSOCIATION_LANE_X = VPC_X - 2 * PAD;
const ASSOCIATION_PITCH = 18; // between the three line ends on the load balancer
const ASSOCIATION_LABEL_X = (LEFT.x + LEFT.w + ASSOCIATION_LANE_X) / 2;
const associate = (i, props) =>
  arrow({
    flow: "association", to: alb, fromSide: "right", toSide: "left", toAt: PUBLIC_MID_Y + (i - 1) * ASSOCIATION_PITCH,
    route: "elbow", mid: ASSOCIATION_LANE_X, labelSegment: 0, labelAt: ASSOCIATION_LABEL_X, gap: ASSOCIATION_END_GAP, ...props,
  });
// CI roles to the Terraform state they work on. An identity provider opens no
// connection, so these are not arrows: the lines say which resources the
// roles in that box are for. Each runs straight down to the middle of its
// box. A vertical line cannot carry its label, so the label sits beside it,
// on the right like every unnumbered caption.
const stateLink = (target, props) =>
  arrow({
    flow: "association", from: githubOidc, to: target, fromSide: "bottom", toSide: "top", fromAt: midX(target),
    labelSide: "right", gap: ASSOCIATION_END_GAP, ...props,
  });
const associations = [
  associate(0, { id: "assoc-alias", from: route53, label: "alias" }),
  associate(1, { id: "assoc-certificate", from: acm, label: "TLS certificate" }),
  associate(2, { id: "assoc-web-acl", from: waf, label: "web ACL" }),
  stateLink(stateBucket, { id: "assoc-state", label: "state" }),
  stateLink(lockTable, { id: "assoc-lock", label: "lock" }),
];

// ===================================================================== legend
//
// A strip below the cloud, outside every frame: it describes the drawing, it
// is not part of the architecture. Each column is as wide as its widest row:
// the line sample, where the row has one, plus the label at legend size.

const LEGEND_GAP = PAD; // cloud to legend
const LEGEND_COLUMN_W = {
  traffic: LEGEND_SAMPLE_ROOM + 416, // "Internal, inside the VPC: one security group rule pair per flow" (414 wide)
  other: LEGEND_SAMPLE_ROOM + 277, // "Control plane and nodes, both directions" (275 wide)
  rules: 306, // "Arrow direction = who opens the connection." (304 wide), a row without a sample
};
const legendPanel = legend({
  x: CLOUD.x, y: CLOUD.h + LEGEND_GAP,
  columns: [
    {
      w: LEGEND_COLUMN_W.traffic,
      rows: [
        { flow: "public", label: "Public-facing: from the internet" },
        { flow: "egress", label: "Outbound only, through NAT" },
        { flow: "internal", label: "Internal, inside the VPC: one security group rule pair per flow" },
      ],
    },
    {
      w: LEGEND_COLUMN_W.other,
      rows: [
        { flow: "control", label: "Control plane and nodes, both directions" },
        { flow: "api", label: "AWS API, identity and telemetry" },
        { flow: "association", label: "Association, not traffic" },
      ],
    },
    {
      w: LEGEND_COLUMN_W.rules,
      rows: [
        { label: "Arrow direction = who opens the connection." },
        { label: "No arrow starts in the data tier." },
        { tag: "SG: x", label: "= security group attached" },
      ],
    },
  ],
});

// The note sits in the space right of the legend, on two lines, and has to
// end before the right edge of the cloud. Its first line starts level with
// the legend's title.
const NOTE_GAP = 2 * PAD; // legend to note
const note = text({
  id: "note", x: legendPanel.x + legendPanel.width + NOTE_GAP, y: legendPanel.titleY, fontSize: SIZE.legend, endsBefore: CLOUD.x + CLOUD.w,
  text: "Production account shown. Dev is a second AWS account built from the same code with different variable values:\ntwo AZs, one NAT gateway, single-AZ RDS and Redis, two Kafka brokers.",
});

// ====================================================================== scene

// Array order is z-order: containers from the outside in, then boxes, then
// arrows, then the legend. The one exception is the internet gateway, which
// goes after arrow 1 so that the arrow passes behind it.
const layers = [
  cloud, region, edge, bootstrap, regional, vpc,
  publicTier.band, appTier.band, dataTier.band, nodeGroup,
  ...publicTier.chips, ...appTier.chips, ...dataTier.chips,
  clients, githubActions, route53, acm, waf, alb, nat, lbc, addons, migrationJob, pods, rds, redis, msk, s3Endpoint, controlPlane,
  ecr, sns, cloudwatch, secrets, iam, kms, githubOidc, stateBucket, lockTable,
  publicEntry, igw,
  ...internal, ...egress, controlLink, ...awsApi, ...associations,
  legendPanel,
];

export default function buildScene() {
  return {
    skeleton: [...layers.flatMap((layer) => layer.elements), note],
    options: { scale: 2, padding: 24, background: "#ffffff" },
  };
}

// -------------------------------------------------------------------- helpers

function midX(shape) {
  return shape.x + shape.width / 2;
}
