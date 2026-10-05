using UnityEngine;

namespace StickWars
{
    // Псевдо-3D переход: камера на мгновение становится перспективной и облетает бойцов,
    // слои фона расходятся по глубине, под ногами появляется пол — как 3D-кадры в стикмен-анимациях.
    public partial class Battle
    {
        bool c3d;
        float c3dT, c3dDur, c3dYaw0, c3dYaw1, c3dDist0, c3dDist1, c3dPitch, c3dCooldown;
        Vector2 c3dFocus;
        GameObject floor3d;
        MeshRenderer floorMr;

        public bool In3D { get { return c3d; } }

        public void Cinematic3D(Vector2 focus, float dur, float yawFrom, float yawTo, float distFrom = 7f, float distTo = 5f)
        {
            if (Game.I != null && !Game.I.S.cine3d) return;
            if (mode == Mode.Showroom || mode == Mode.Demo) return;
            if (c3d) { c3dFocus = focus; c3dT = 0; c3dDur = dur; return; }
            c3d = true; c3dT = 0f; c3dDur = dur;
            c3dFocus = focus + Vector2.up * 0.4f;
            c3dYaw0 = yawFrom; c3dYaw1 = yawTo; c3dDist0 = distFrom; c3dDist1 = distTo;
            c3dPitch = Random.Range(4f, 12f);
            var c = cam.cam;
            c.orthographic = false;
            c.fieldOfView = 40f;
            c.nearClipPlane = 0.05f;
            c.farClipPlane = 200f;
            ShowFloor();
            theme.SetDepth(false, Vector2.zero, 7f);
            theme.Follow(cam2D);
            theme.SetDepth(true, c3dFocus, distFrom);
            Flash(0.07f, new Color(1, 1, 1, 0.6f));
            audio.Sfx("cine", 0.6f, 0f);
        }

        void ShowFloor()
        {
            EnsureFloor();
            floor3d.SetActive(true);
            Color fc = curStyle == 0 ? theme.groundCol : sgFill != null ? sgFill.color : theme.groundCol;
            var m = floor3d.GetComponent<MeshFilter>().sharedMesh;
            var cols = new Color[4];
            for (int i = 0; i < 4; i++) cols[i] = i < 2 ? fc : Color.Lerp(fc, cam.cam.backgroundColor, 0.6f);
            m.colors = cols;
        }

        // ===== постоянный 3D-вид: камера всегда перспективная, слегка сверху и сбоку, медленно «дышит» вокруг боя =====
        bool alwaysOn;
        float a3Yaw, a3T;
        public bool Always3D
        {
            get { return Game.I != null && Game.I.S.always3d && mode != Mode.Showroom && mode != Mode.Replay; }
        }

        void Always3DTick(float raw)
        {
            var c = cam.cam;
            if (!Always3D)
            {
                if (alwaysOn)
                {
                    alwaysOn = false;
                    c.orthographic = true; c.nearClipPlane = 0.1f; c.farClipPlane = 100f;
                    c.transform.rotation = Quaternion.identity;
                    if (floor3d != null) floor3d.SetActive(false);
                    theme.SetDepth(false, Vector2.zero, 7f);
                }
                return;
            }
            if (!alwaysOn) { alwaysOn = true; a3Yaw = 0f; }
            a3T += raw;
            // CameraDirector уже посчитал 2D-кадр: центр и размер — переводим в перспективу
            float size = c.orthographicSize;
            Vector3 p = c.transform.position;
            float shakeRoll = c.transform.eulerAngles.z;
            c.orthographic = false;
            c.fieldOfView = 42f;
            c.nearClipPlane = 0.05f; c.farClipPlane = 220f;
            // лёгкий поворот в сторону движения боя + медленное покачивание
            float drift = Mathf.Clamp((p.x - a3LastX) / Mathf.Max(raw, 0.001f), -8f, 8f);
            a3LastX = p.x;
            float targetYaw = Mathf.Sin(a3T * 0.23f) * 11f - drift * 1.2f;
            a3Yaw = Mathf.Lerp(a3Yaw, targetYaw, 1f - Mathf.Exp(-raw * 1.5f));
            float pitch = 9f + Mathf.Sin(a3T * 0.17f) * 2.5f;
            float dist = size / Mathf.Tan(21f * Mathf.Deg2Rad);
            var rot = Quaternion.Euler(pitch, a3Yaw, shakeRoll);
            Vector3 target = new Vector3(p.x, p.y - 0.4f, 0f);
            c.transform.rotation = rot;
            c.transform.position = target + rot * new Vector3(0f, 0f, -dist);
            if (floor3d == null || !floor3d.activeSelf || a3FloorStyle != curStyle) { ShowFloor(); a3FloorStyle = curStyle; }
            theme.SetDepth(false, Vector2.zero, 7f);
            theme.Follow(new Vector3(p.x, p.y, 0f));
            theme.SetDepth(true, target, dist);
        }
        float a3LastX;
        Vector3 cam2D;
        int a3FloorStyle = -1;

        void EnsureFloor()
        {
            if (floor3d != null) return;
            floor3d = new GameObject("Floor3D");
            floor3d.transform.SetParent(transform, false);
            var mf = floor3d.AddComponent<MeshFilter>();
            floorMr = floor3d.AddComponent<MeshRenderer>();
            var mesh = new Mesh();
            mesh.vertices = new[] { new Vector3(-90, 0, -12), new Vector3(90, 0, -12), new Vector3(90, 0, 120), new Vector3(-90, 0, 120) };
            mesh.uv = new[] { Vector2.zero, Vector2.right, Vector2.one, Vector2.up };
            mesh.colors = new[] { Color.gray, Color.gray, Color.gray, Color.gray };
            mesh.triangles = new[] { 0, 2, 1, 0, 3, 2 };
            mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 500f);
            mf.sharedMesh = mesh;
            floorMr.sharedMaterial = Draw.LineMat;
            floorMr.sortingOrder = -11;
            floor3d.SetActive(false);
        }

        void Cine3DTick(float raw)
        {
            c3dT += raw;
            float k = Mathf.Clamp01(c3dT / c3dDur);
            float e = 1f - (1f - k) * (1f - k);
            float yaw = Mathf.Lerp(c3dYaw0, c3dYaw1, e);
            float dist = Mathf.Lerp(c3dDist0, c3dDist1, e);
            var rot = Quaternion.Euler(c3dPitch, yaw, Mathf.Sin(c3dT * 2f) * 1.5f);
            Vector3 target = new Vector3(c3dFocus.x, Mathf.Max(c3dFocus.y, 1.2f), 0f);
            var t = cam.cam.transform;
            t.rotation = rot;
            t.position = target + rot * new Vector3(0f, 0f, -dist);
            if (k >= 1f) End3D();
        }

        public void End3D()
        {
            if (!c3d) return;
            c3d = false;
            c3dCooldown = 2.5f;
            var c = cam.cam;
            c.orthographic = true;
            c.nearClipPlane = 0.1f;
            c.farClipPlane = 100f;
            c.transform.rotation = Quaternion.identity;
            if (floor3d != null && !Always3D) floor3d.SetActive(false);
            theme.SetDepth(false, Vector2.zero, 7f);
            Flash(0.05f, new Color(1, 1, 1, 0.5f));
        }
    }
}
