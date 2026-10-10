using UnityEngine;

// Камера наблюдателя (режим TABS): свободный полёт или слежение за бойцами (Tab)
public class SpectatorCam : MonoBehaviour
{
    public static SpectatorCam I;
    public Unit follow;
    float yaw, pitch;
    Vector3 vel;
    int followIdx = -1;
    float followDist = 4.5f;

    public static bool Active => I != null && I.enabled;

    public static void Activate(Vector3 pos, Quaternion rot)
    {
        var cam = Game.Cam;
        cam.transform.SetParent(null, true);
        cam.transform.SetPositionAndRotation(pos, rot);
        cam.cullingMask = ~(1 << Layers.ViewModel);
        cam.nearClipPlane = 0.1f;
        cam.fieldOfView = Game.Fov;
        if (I == null) I = cam.gameObject.AddComponent<SpectatorCam>();
        I.enabled = true;
        var e = rot.eulerAngles;
        I.yaw = e.y; I.pitch = e.x > 180 ? e.x - 360 : e.x;
        I.follow = null;
    }

    public static void Deactivate()
    {
        if (I != null) { I.enabled = false; I.follow = null; }
    }

    public void Cycle(int dir)
    {
        var list = Unit.All.FindAll(u => u != null && u.alive && !u.inVehicle);
        if (list.Count == 0) { follow = null; return; }
        followIdx = ((followIdx + dir) % list.Count + list.Count) % list.Count;
        follow = list[followIdx];
    }

    void LateUpdate()
    {
        if (Game.Paused) return;
        float dt = Time.unscaledDeltaTime;
        var t = transform;
        bool look = Cursor.lockState == CursorLockMode.Locked || Input.GetMouseButton(1);
        if (look)
        {
            yaw += Input.GetAxisRaw("Mouse X") * Game.Sensitivity;
            pitch = Mathf.Clamp(pitch - Input.GetAxisRaw("Mouse Y") * Game.Sensitivity, -89f, 89f);
        }
        if (Input.GetKeyDown(KeyCode.Tab)) Cycle(Input.GetKey(KeyCode.LeftShift) ? -1 : 1);
        if (Input.GetKeyDown(KeyCode.Space)) follow = null;
        followDist = Mathf.Clamp(followDist - Input.GetAxis("Mouse ScrollWheel") * 6f, 1.5f, 25f);

        if (follow != null && (!follow.alive))
        {
            // показываем падение тела ещё пару секунд
            if (Time.time - follow.deathTime > 3f) Cycle(1);
        }
        Quaternion rot = Quaternion.Euler(pitch, yaw, 0);
        if (follow != null)
        {
            Vector3 focus = follow.alive ? follow.AimPoint : follow.transform.position + Vector3.up;
            var rd = follow.GetComponent<Ragdoll>();
            if (!follow.alive && rd != null && rd.parts.Count > 0) focus = rd.parts[0].t.position + Vector3.up * 0.3f;
            Vector3 want = focus - rot * Vector3.forward * followDist + rot * new Vector3(0.6f, 0.3f, 0);
            // не заходим под землю и в стены
            if (Physics.SphereCast(focus, 0.2f, (want - focus).normalized, out var hit, Vector3.Distance(focus, want), 1 << Layers.World, QueryTriggerInteraction.Ignore))
                want = hit.point + hit.normal * 0.3f;
            t.position = Vector3.Lerp(t.position, want, 1f - Mathf.Exp(-8f * dt));
            t.rotation = Quaternion.Slerp(t.rotation, rot, 1f - Mathf.Exp(-12f * dt));
        }
        else
        {
            Vector3 input = new Vector3((Input.GetKey(KeyCode.D) ? 1 : 0) - (Input.GetKey(KeyCode.A) ? 1 : 0),
                (Input.GetKey(KeyCode.E) ? 1 : 0) - (Input.GetKey(KeyCode.Q) ? 1 : 0),
                (Input.GetKey(KeyCode.W) ? 1 : 0) - (Input.GetKey(KeyCode.S) ? 1 : 0));
            float sp = Input.GetKey(KeyCode.LeftShift) ? 45f : 15f;
            Vector3 target = rot * input * sp;
            vel = Vector3.Lerp(vel, target, 1f - Mathf.Exp(-6f * dt));
            t.position += vel * dt;
            float gy = Battle.GroundHeight(t.position) + 1f;
            if (t.position.y < gy) t.position = new Vector3(t.position.x, gy, t.position.z);
            t.rotation = Quaternion.Slerp(t.rotation, rot, 1f - Mathf.Exp(-15f * dt));
        }
        t.position += Fx.ShakeOffset;
    }
}
