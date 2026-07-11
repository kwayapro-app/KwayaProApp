import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { defineSecret } from "firebase-functions/params";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const r2AccountId = defineSecret("R2_ACCOUNT_ID");
const r2BucketName = defineSecret("R2_BUCKET_NAME");
const r2AccessKey = defineSecret("R2_ACCESS_KEY_ID");
const r2SecretKey = defineSecret("R2_SECRET_ACCESS_KEY");

export const getR2PresignedUploadChannel = onRequest(
  { cors: true, secrets: [r2AccountId, r2BucketName, r2AccessKey, r2SecretKey] },
  async (req, res) => {
    try {
      const { choirId, songId, sectionId, voicePart, mimeType } = req.body;
      const authHeader = req.headers.authorization;

      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        res.status(401).json({ error: "Unauthorized: Missing validation context" });
        return;
      }

      if (!choirId || !songId || !sectionId || !voicePart) {
        res.status(400).json({ error: "Missing required fields" });
        return;
      }

      const token = authHeader.split("Bearer ")[1];
      const decodedToken = await admin.auth().verifyIdToken(token);
      const uid = decodedToken.uid;

      const membershipDoc = await admin.firestore()
        .collection("choir_memberships")
        .doc(`${choirId}_${uid}`)
        .get();

      if (!membershipDoc.exists) {
        res.status(403).json({ error: "Forbidden: Insufficient tenant authorization" });
        return;
      }

      const membershipData = membershipDoc.data()!;
      const isAuthorized = membershipData.role === "leader" ||
        membershipData.role === "director" ||
        (membershipData.permissions as string[] | undefined)?.includes("audio_uploader");

      if (!isAuthorized) {
        res.status(403).json({ error: "Forbidden: Write privileges missing" });
        return;
      }

      const extension = mimeType === "audio/aac" ? "aac" : "m4a";
      const objectStorageKey = `choirs/${choirId}/songs/${songId}/sections/${sectionId}/${voicePart}.${extension}`;

      const accountId = r2AccountId.value();
      const accessKey = r2AccessKey.value();
      const secretKey = r2SecretKey.value();
      const bucket = r2BucketName.value();

      const r2Client = new S3Client({
        region: "auto",
        endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
        credentials: {
          accessKeyId: accessKey,
          secretAccessKey: secretKey,
        },
        requestHandler: {
          requestTimeout: 30000,
        },
      });

      const command = new PutObjectCommand({
        Bucket: bucket,
        Key: objectStorageKey,
        ContentType: mimeType || "audio/m4a",
      });

      const presignedUrl = await getSignedUrl(r2Client, command, { expiresIn: 900 });

      res.status(200).json({
        uploadUrl: presignedUrl,
        targetObjectKey: objectStorageKey,
      });
    } catch (error) {
      logger.error("R2 presigned URL generation failed", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);
