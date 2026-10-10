using UnityEngine;

public enum AnimStyle { Soldier, Zombie, Shy, ShyRage, Doctor, Old, Burning }

// Жесты командира
public enum Signal { None, Point, MoveUp, Hold, Regroup }

// Процедурная анимация человека.
// Каждое состояние (покой, ходьба, бег, стрейф, присед, прицел, перезарядка, бросок, удар, сидение, канат, прыжок,
// жесты, бездействие, ранение, падение) — это вес, который меняется плавно; итоговая поза каждой кости догоняет
// целевую с экспоненциальным сглаживанием, поэтому любые переходы мягкие. Поверх — IK рук на оружии и IK ног по земле.
[DefaultExecutionOrder(100)]
public class HumanAnimator : MonoBehaviour
{
    public HumanRig rig;
    public AnimStyle style = AnimStyle.Soldier;

    // ---- входные параметры (выставляет ИИ / контроллер) ----
    public Vector3 velocity;
    public Vector3 aimDir = Vector3.forward;
    public bool aiming, crouch, sprint, seated, onRope, airborne, slung, handsOnFace, kneel;
    public float reload01 = -1f, throw01 = -1f, attack01 = -1f, melee01 = -1f;
    public bool reloadEmpty;          // перезарядка пустого оружия — в конце передёргивается затвор
    public float shellPhase;          // дробовик: фаза зарядки патрона 0..1
    public float mouth;               // 0..1 открытие рта (096)
    public float hunch;               // дополнительная сутулость
    public float wounded;             // 0..1 ранение: хромота, рука на боку
    public float suppressed;          // 0..1 под огнём: пригибается
    public float dying = -1f;         // 0..1 подгибание перед падением (затем — физика)
    public GunModel gun;
    public Vector3 ropePoint;
    public float speedMul = 1f;
    public bool footsteps = true;
    public bool idleActs = true;
    public bool footIK = true;

    // ---- внутреннее состояние ----
    float phase, spd;
    Vector2 moveDir = new Vector2(0, 1);
    float crouchW, aimW, seatW, ropeW, airW, sprintW, gunW = 1f, faceW, kneelW, landW, reloadW, throwW, attackW, meleeW, deathW, woundW, suppW;
    readonly Quaternion[] cur = new Quaternion[HumanRig.Count];
    readonly Vector3[] tgt = new Vector3[HumanRig.Count];
    readonly Vector3[] react = new Vector3[HumanRig.Count];   // реакции на попадания (по костям)
    Vector3 hipsCur, hipsReact;
    bool init;
    Quaternion pivotRot = Quaternion.identity;
    Vector3 pivotPos;
    Vector3 kick, kickVel;
    float snapW, snapDur = 1f;
    readonly Quaternion[] snap = new Quaternion[HumanRig.Count];
    Vector3 snapHips;
    float t0;
    Vector3 prevVel, accelL;      // ускорение в локальных координатах
    float prevYaw, yawRate;
    float hipsYawCur;
    float footDropL, footDropR, hipsDrop;
    // бездействие
    int idleAct = -1; float idleT, idleDur, nextIdle;
    // жесты
    Signal signal; float signalT = -1f;

    public float Phase => phase;

    void Start()
    {
        t0 = Random.Range(0f, 100f);
        nextIdle = Time.time + Random.Range(3f, 9f);
    }

    void InitPose()
    {
        for (int i = 0; i < HumanRig.Count; i++) cur[i] = rig.b[i].localRotation;
        hipsCur = rig.b[HumanRig.Hips].localPosition;
        pivotPos = rig.aimPivot.localPosition;
        prevYaw = transform.eulerAngles.y;
        init = true;
    }

    public void Kick(float up, float back) { kickVel += new Vector3(-up * 60f, 0, -back * 3f); }

    // Реакция на попадание: зависит от того, куда попали
    public void Flinch(Vector3 worldDir, float amount) => HitReact(worldDir, amount, HumanRig.Chest);

    public void HitReact(Vector3 worldDir, float amount, int bone)
    {
        Vector3 l = transform.InverseTransformDirection(worldDir);
        amount = Mathf.Clamp(amount, 0f, 1.6f);
        switch (bone)
        {
            case HumanRig.Head: case HumanRig.Neck:
                react[HumanRig.Head] += new Vector3(-l.z * 35f, l.x * 20f, -l.x * 30f) * amount;
                react[HumanRig.Neck] += new Vector3(-l.z * 15f, 0, -l.x * 12f) * amount;
                break;
            case HumanRig.ULegL: case HumanRig.LLegL: case HumanRig.FootL:
                react[HumanRig.ULegL] += new Vector3(-25f, 0, 0) * amount; react[HumanRig.LLegL] += new Vector3(50f, 0, 0) * amount;
                hipsReact += new Vector3(-0.04f, -0.12f, 0) * amount; react[HumanRig.Hips] += new Vector3(0, 0, 8f) * amount;
                break;
            case HumanRig.ULegR: case HumanRig.LLegR: case HumanRig.FootR:
                react[HumanRig.ULegR] += new Vector3(-25f, 0, 0) * amount; react[HumanRig.LLegR] += new Vector3(50f, 0, 0) * amount;
                hipsReact += new Vector3(0.04f, -0.12f, 0) * amount; react[HumanRig.Hips] += new Vector3(0, 0, -8f) * amount;
                break;
            case HumanRig.UArmL: case HumanRig.LArmL: case HumanRig.HandL:
                react[HumanRig.Chest] += new Vector3(l.z * 10f, -25f, 10f) * amount; react[HumanRig.UArmL] += new Vector3(30f, 0, -20f) * amount;
                break;
            case HumanRig.UArmR: case HumanRig.LArmR: case HumanRig.HandR:
                react[HumanRig.Chest] += new Vector3(l.z * 10f, 25f, -10f) * amount; react[HumanRig.UArmR] += new Vector3(30f, 0, 20f) * amount;
                break;
            default:
                react[HumanRig.Spine] += new Vector3(l.z * 22f, -l.x * 10f, -l.x * 18f) * amount;
                react[HumanRig.Chest] += new Vector3(l.z * 18f, -l.x * 14f, -l.x * 14f) * amount;
                react[HumanRig.Head] += new Vector3(l.z * 10f, 0, 0) * amount;
                hipsReact += new Vector3(0, -0.03f, -l.z * 0.04f) * amount;
                break;
        }
        for (int i = 0; i < react.Length; i++) react[i] = Vector3.ClampMagnitude(react[i], 60f);
        hipsReact = Vector3.ClampMagnitude(hipsReact, 0.2f);
        idleAct = -1;
    }

    public void DoSignal(Signal s)
    {
        signal = s; signalT = 0f;
        idleAct = -1;
    }

    public bool Signaling => signalT >= 0;

    public void BlendFromCurrent(float duration)
    {
        if (!init) InitPose();
        for (int i = 0; i < HumanRig.Count; i++) { snap[i] = rig.b[i].localRotation; cur[i] = snap[i]; }
        snapHips = rig.b[HumanRig.Hips].localPosition;
        hipsCur = snapHips;
        snapW = 1f;
        snapDur = duration;
    }

    public void Snap() { init = false; }

    static float Damp(float a, float b, float k, float dt) => Mathf.Lerp(a, b, 1f - Mathf.Exp(-k * dt));
    static float S01(float a, float b, float t) => Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(a, b, t));
    static float Bell(float a, float b, float t) { float k = Mathf.InverseLerp(a, b, t); return k <= 0 || k >= 1 ? 0 : Mathf.Sin(k * Mathf.PI); }

    void LateUpdate()
    {
        if (rig == null) return;
        if (!init) InitPose();
        float dt = Mathf.Min(Time.deltaTime, 0.05f);
        if (dt <= 0) return;
        float time = Time.time + t0;
        bool hasGun = gun != null && style == AnimStyle.Soldier;
        bool pistol = hasGun && gun.def.kind == WeaponKind.Pistol;
        float scaleK = transform.lossyScale.y;
        float legLen = rig.shape.legU + rig.shape.legL;
        float legK = legLen / 0.89f;

        // ---- движение тела: скорость, ускорение, поворот ----
        Vector3 lv = transform.InverseTransformDirection(velocity);
        lv.y = 0;
        float rawSpd = lv.magnitude;
        spd = Damp(spd, rawSpd, 8f, dt);
        Vector3 acc = transform.InverseTransformDirection((velocity - prevVel) / dt);
        prevVel = velocity;
        accelL = Vector3.Lerp(accelL, Vector3.ClampMagnitude(acc, 20f), 1f - Mathf.Exp(-5f * dt));
        float yawNow = transform.eulerAngles.y;
        float yr = Mathf.DeltaAngle(prevYaw, yawNow) / dt;
        prevYaw = yawNow;
        yawRate = Damp(yawRate, Mathf.Clamp(yr, -400f, 400f), 6f, dt);
        if (rawSpd > 0.2f) moveDir = Vector2.Lerp(moveDir, new Vector2(lv.x, lv.z) / rawSpd, 1f - Mathf.Exp(-10f * dt));

        // ---- веса состояний ----
        crouchW = Damp(crouchW, crouch && !seated && !onRope ? 1f : 0f, 7f, dt);
        aimW = Damp(aimW, aiming && hasGun && !sprint ? 1f : 0f, 9f, dt);
        sprintW = Damp(sprintW, sprint && rawSpd > 3f ? 1f : 0f, 6f, dt);
        seatW = Damp(seatW, seated ? 1f : 0f, 5f, dt);
        ropeW = Damp(ropeW, onRope ? 1f : 0f, 8f, dt);
        bool wasAir = airW > 0.5f;
        airW = Damp(airW, airborne ? 1f : 0f, 9f, dt);
        if (wasAir && !airborne) landW = 1f;
        landW = Damp(landW, 0f, 3.5f, dt);
        gunW = Damp(gunW, hasGun && !slung && !onRope && dying < 0 ? 1f : 0f, dying >= 0 ? 14f : 6f, dt);
        faceW = Damp(faceW, handsOnFace ? 1f : 0f, 4f, dt);
        kneelW = Damp(kneelW, kneel ? 1f : 0f, 4f, dt);
        reloadW = Damp(reloadW, reload01 >= 0 ? 1f : 0f, 10f, dt);
        throwW = Damp(throwW, throw01 >= 0 ? 1f : 0f, 14f, dt);
        attackW = Damp(attackW, attack01 >= 0 ? 1f : 0f, 14f, dt);
        meleeW = Damp(meleeW, melee01 >= 0 ? 1f : 0f, 16f, dt);
        deathW = Damp(deathW, dying >= 0 ? 1f : 0f, 12f, dt);
        woundW = Damp(woundW, wounded, 2f, dt);
        suppW = Damp(suppW, suppressed, 4f, dt);
        kickVel += (-kick * 220f - kickVel * 22f) * dt;
        kick += kickVel * dt;
        for (int i = 0; i < react.Length; i++) react[i] = Vector3.Lerp(react[i], Vector3.zero, 1f - Mathf.Exp(-5.5f * dt));
        hipsReact = Vector3.Lerp(hipsReact, Vector3.zero, 1f - Mathf.Exp(-5f * dt));
        if (signalT >= 0) { signalT += dt / 1.6f; if (signalT >= 1f) signalT = -1f; }

        float free = (1f - seatW) * (1f - ropeW) * (1f - airW) * (1f - kneelW);
        float move = Mathf.Clamp01(spd / (0.9f * scaleK)) * free;
        float run = Mathf.InverseLerp(3.2f * scaleK, 6.5f * scaleK, spd);
        // поворот на месте — мелкие переступания
        float turnStep = Mathf.Clamp01(Mathf.Abs(yawRate) / 120f) * (1f - Mathf.Clamp01(spd)) * free;
        float stride = Mathf.Lerp(1.15f, 2.4f, run) * legK * (1f - crouchW * 0.4f);
        if (style == AnimStyle.ShyRage) stride *= 1.4f;
        float prevPhase = phase;
        phase += (spd / Mathf.Max(0.3f, stride) + turnStep * 1.6f) * Mathf.PI * 2f * dt;
        if (phase > Mathf.PI * 1000f) phase -= Mathf.PI * 1000f;
        float stepAmt = Mathf.Max(move, turnStep * 0.35f);

        // шаги: звук в момент постановки ноги
        if (footsteps && stepAmt > 0.25f && Mathf.Floor((prevPhase + Mathf.PI * 0.5f) / Mathf.PI) != Mathf.Floor((phase + Mathf.PI * 0.5f) / Mathf.PI))
        {
            var cam = Camera.main;
            if (cam != null && (cam.transform.position - transform.position).sqrMagnitude < 900f)
                Sfx.Play("step", transform.position, 0.1f + run * 0.15f, Random.Range(0.85f, 1.15f), 25f);
        }

        // ---- бездействие ----
        bool idleOk = idleActs && style == AnimStyle.Soldier && rawSpd < 0.3f && !aiming && reload01 < 0 && throw01 < 0 && melee01 < 0 && signalT < 0 && dying < 0 && !onRope && !airborne && hasGun;
        if (!idleOk) idleAct = -1;
        else if (idleAct < 0 && Time.time > nextIdle)
        {
            idleAct = seated ? (Random.value < 0.6f ? 0 : 1) : Random.Range(0, 6);
            idleT = 0f;
            idleDur = new[] { 3.2f, 2.6f, 1.8f, 4f, 2.2f, 1.4f }[idleAct];
        }
        float idleW = 0f;
        if (idleAct >= 0)
        {
            idleT += dt / idleDur;
            idleW = S01(0f, 0.18f, idleT) * (1f - S01(0.82f, 1f, idleT));
            if (idleT >= 1f) { idleAct = -1; nextIdle = Time.time + Random.Range(4f, 12f); }
        }

        for (int i = 0; i < HumanRig.Count; i++) tgt[i] = Vector3.zero;
        Vector3 hipsOff = Vector3.zero;

        // ---- разворот таза в сторону движения (стрейф / бег спиной) ----
        float moveYaw = Mathf.Atan2(moveDir.x, moveDir.y) * Mathf.Rad2Deg;
        bool backward = moveDir.y < -0.3f;
        float legYawTarget = 0f;
        if (move > 0.2f)
        {
            legYawTarget = backward ? Mathf.DeltaAngle(180f, moveYaw) : moveYaw;
            legYawTarget = Mathf.Clamp(legYawTarget, -50f, 50f) * (1f - crouchW * 0.4f);
        }
        hipsYawCur = Damp(hipsYawCur, legYawTarget, 6f, dt);
        float hy = hipsYawCur * Mathf.Deg2Rad;
        Vector2 legDir = new Vector2(moveDir.x * Mathf.Cos(hy) - moveDir.y * Mathf.Sin(hy), moveDir.x * Mathf.Sin(hy) + moveDir.y * Mathf.Cos(hy));
        float fwd = legDir.y, side = legDir.x;

        // ---------------- НОГИ ----------------
        float s = Mathf.Sin(phase), c = Mathf.Cos(phase);
        float amp = Mathf.Lerp(24f, 50f, run) * stepAmt * (1f - crouchW * 0.3f);
        float kneeAmp = Mathf.Lerp(38f, 100f, run) * stepAmt;
        float limp = style == AnimStyle.Zombie ? 0.55f : 1f - woundW * 0.45f;
        float sL = s, sR = -s, cL = c, cR = -c;
        float swingL = sL * amp, swingR = sR * amp * limp;
        tgt[HumanRig.ULegL] = new Vector3(-swingL * fwd, 0, swingL * side * 0.6f);
        tgt[HumanRig.ULegR] = new Vector3(-swingR * fwd, 0, swingR * side * 0.6f);
        // колено сгибается при выносе ноги, слегка амортизирует при постановке
        float kL = 5f + Mathf.Max(0, cL) * kneeAmp + Mathf.Max(0, -cL) * Mathf.Max(0, sL) * 12f * stepAmt;
        float kR = 5f + Mathf.Max(0, cR) * kneeAmp * limp + Mathf.Max(0, -cR) * Mathf.Max(0, sR) * 12f * stepAmt;
        if (backward) { kL = 5f + Mathf.Max(0, -cL) * kneeAmp * 0.7f; kR = 5f + Mathf.Max(0, -cR) * kneeAmp * 0.7f; }
        tgt[HumanRig.LLegL] = new Vector3(kL, 0, 0);
        tgt[HumanRig.LLegR] = new Vector3(kR, 0, 0);
        if (run > 0.1f) { tgt[HumanRig.ULegL].x -= run * 12f; tgt[HumanRig.ULegR].x -= run * 12f; }
        // таз: ниже всего, когда ноги расставлены; смещение веса на опорную ногу; наклон и поворот
        hipsOff.y += (-Mathf.Abs(s) * (0.028f + run * 0.035f) + 0.015f) * stepAmt - run * 0.05f;
        hipsOff.x += -c * 0.022f * stepAmt * (1f - run * 0.5f);
        tgt[HumanRig.Hips].y += hipsYawCur + s * 7f * stepAmt * fwd;
        tgt[HumanRig.Hips].z += c * 4f * stepAmt;
        // наклон от ускорения и крен в повороте
        float leanF = Mathf.Clamp(accelL.z * 1.3f, -10f, 12f) * free;
        float bank = Mathf.Clamp(-yawRate * spd * 0.012f, -12f, 12f) * free;
        tgt[HumanRig.Hips].z += bank * 0.6f;
        tgt[HumanRig.Spine].x += leanF * 0.6f;
        tgt[HumanRig.Chest].x += leanF * 0.4f;

        // боевая стойка на месте: левая нога вперёд, корпус чуть развёрнут
        float stanceW = aimW * (1f - move) * free * (pistol ? 0.4f : 1f);
        tgt[HumanRig.ULegL] += new Vector3(-12f, 0, -5f) * stanceW;
        tgt[HumanRig.LLegL] += new Vector3(14f, 0, 0) * stanceW;
        tgt[HumanRig.ULegR] += new Vector3(9f, 0, 6f) * stanceW;
        tgt[HumanRig.LLegR] += new Vector3(10f, 0, 0) * stanceW;
        tgt[HumanRig.Hips].y += 22f * stanceW;
        hipsOff.y -= 0.03f * stanceW;
        // расслабленная стойка: ноги шире, вес на одной ноге
        float relaxW = (1f - aimW) * (1f - move) * free * (1f - crouchW) * (style == AnimStyle.Soldier ? 1f : 0.4f);
        float shift = Mathf.Sin(time * 0.35f) * 0.5f + 0.5f;
        tgt[HumanRig.ULegL] += new Vector3(-2f, 0, -5f) * relaxW;
        tgt[HumanRig.ULegR] += new Vector3(-2f, 0, 5f) * relaxW;
        tgt[HumanRig.LLegL] += new Vector3(8f * shift, 0, 0) * relaxW;
        tgt[HumanRig.LLegR] += new Vector3(8f * (1f - shift), 0, 0) * relaxW;
        hipsOff.x += (shift - 0.5f) * 0.03f * relaxW;
        tgt[HumanRig.Hips].z += (shift - 0.5f) * 5f * relaxW;

        // присед (на ходу — короткие шаги на полусогнутых)
        if (crouchW > 0.001f)
        {
            float cw = crouchW * (1f - seatW);
            tgt[HumanRig.ULegL] += new Vector3(-72f, 0, -6f) * cw;
            tgt[HumanRig.ULegR] += new Vector3(-48f, 0, 6f) * cw;
            tgt[HumanRig.LLegL] += new Vector3(100f, 0, 0) * cw;
            tgt[HumanRig.LLegR] += new Vector3(118f, 0, 0) * cw;
            hipsOff.y -= 0.35f * legK * cw;
            hipsOff.z -= 0.08f * cw;
            tgt[HumanRig.Spine].x += 16f * cw;
        }
        // под огнём — пригибается
        if (suppW > 0.01f && seatW < 0.5f)
        {
            tgt[HumanRig.Spine].x += 14f * suppW; tgt[HumanRig.Chest].x += 8f * suppW; tgt[HumanRig.Neck].x += 10f * suppW;
            tgt[HumanRig.LLegL].x += 18f * suppW; tgt[HumanRig.LLegR].x += 18f * suppW;
            tgt[HumanRig.ULegL].x -= 10f * suppW; tgt[HumanRig.ULegR].x -= 10f * suppW;
            hipsOff.y -= 0.07f * suppW;
        }
        // приземление — пружинящее приседание
        if (landW > 0.01f)
        {
            tgt[HumanRig.ULegL].x -= 45f * landW; tgt[HumanRig.ULegR].x -= 38f * landW;
            tgt[HumanRig.LLegL].x += 75f * landW; tgt[HumanRig.LLegR].x += 68f * landW;
            hipsOff.y -= 0.25f * legK * landW;
            tgt[HumanRig.Spine].x += 15f * landW;
        }
        // полёт (прыжок из вертолёта)
        if (airW > 0.001f)
        {
            float tuck = Mathf.Sin(time * 3f) * 5f;
            tgt[HumanRig.ULegL] += new Vector3(-55f + tuck, 0, -6f) * airW;
            tgt[HumanRig.ULegR] += new Vector3(-20f - tuck, 0, 6f) * airW;
            tgt[HumanRig.LLegL] += new Vector3(75f, 0, 0) * airW;
            tgt[HumanRig.LLegR] += new Vector3(40f, 0, 0) * airW;
            tgt[HumanRig.Spine].x += 8f * airW;
        }
        // сидение в вертолёте
        if (seatW > 0.001f)
        {
            for (int i = HumanRig.ULegL; i <= HumanRig.FootR; i++) tgt[i] *= 1f - seatW;
            float fidget = Mathf.Sin(time * 0.6f) * 4f;
            tgt[HumanRig.ULegL] += new Vector3(-86f, 0, -8f) * seatW;
            tgt[HumanRig.ULegR] += new Vector3(-88f, 0, 8f) * seatW;
            tgt[HumanRig.LLegL] += new Vector3(80f + fidget, 0, 0) * seatW;
            tgt[HumanRig.LLegR] += new Vector3(92f - fidget, 0, 0) * seatW;
            float ulegY = rig.b[HumanRig.ULegL].localPosition.y;
            Vector3 seatHips = new Vector3(0, (0.47f - ulegY) - rig.hipsRest.y, 0.03f);
            hipsOff = Vector3.Lerp(hipsOff, seatHips, seatW);
            tgt[HumanRig.Spine].x += 6f * seatW;
            tgt[HumanRig.Hips].y *= 1f - seatW;
        }
        // канат: ноги обхватывают
        if (ropeW > 0.001f)
        {
            for (int i = HumanRig.ULegL; i <= HumanRig.FootR; i++) tgt[i] *= 1f - ropeW;
            tgt[HumanRig.ULegL] += new Vector3(-35f, 0, 10f) * ropeW;
            tgt[HumanRig.ULegR] += new Vector3(-12f, 0, -10f) * ropeW;
            tgt[HumanRig.LLegL] += new Vector3(55f, 0, 0) * ropeW;
            tgt[HumanRig.LLegR] += new Vector3(30f, 0, 0) * ropeW;
            tgt[HumanRig.Hips].y *= 1f - ropeW;
        }
        // на колене
        if (kneelW > 0.001f)
        {
            tgt[HumanRig.ULegL] = Vector3.Lerp(tgt[HumanRig.ULegL], new Vector3(-90f, 0, 0), kneelW);
            tgt[HumanRig.LLegL] = Vector3.Lerp(tgt[HumanRig.LLegL], new Vector3(90f, 0, 0), kneelW);
            tgt[HumanRig.ULegR] = Vector3.Lerp(tgt[HumanRig.ULegR], new Vector3(5f, 0, 0), kneelW);
            tgt[HumanRig.LLegR] = Vector3.Lerp(tgt[HumanRig.LLegR], new Vector3(95f, 0, 0), kneelW);
            hipsOff = Vector3.Lerp(hipsOff, new Vector3(0, -rig.shape.legL + 0.02f, -0.15f), kneelW);
            tgt[HumanRig.Spine].x += 25f * kneelW;
        }
        // подгибание при смерти: колени, таз вниз, корпус вперёд
        if (deathW > 0.001f)
        {
            float dk = Mathf.Clamp01(dying) * deathW;
            tgt[HumanRig.ULegL] += new Vector3(-35f, 0, -8f) * dk; tgt[HumanRig.ULegR] += new Vector3(-20f, 0, 10f) * dk;
            tgt[HumanRig.LLegL] += new Vector3(80f, 0, 0) * dk; tgt[HumanRig.LLegR] += new Vector3(65f, 0, 0) * dk;
            hipsOff.y -= 0.3f * legK * dk;
            tgt[HumanRig.Spine].x += 25f * dk; tgt[HumanRig.Chest].x += 15f * dk; tgt[HumanRig.Head].x += 35f * dk;
        }
        // стопы: перекат с пятки на носок и параллельно земле
        float roll = Mathf.Lerp(14f, 24f, run) * stepAmt * (1f - crouchW * 0.6f);
        float rollL = -sL * roll * (fwd >= 0 ? 1 : -1), rollR = -sR * roll * (fwd >= 0 ? 1 : -1);
        tgt[HumanRig.FootL] = new Vector3(-(tgt[HumanRig.ULegL].x + tgt[HumanRig.LLegL].x) * 0.9f * (1f - airW * 0.5f) + rollL * (1f - seatW), 0, -tgt[HumanRig.ULegL].z * 0.5f);
        tgt[HumanRig.FootR] = new Vector3(-(tgt[HumanRig.ULegR].x + tgt[HumanRig.LLegR].x) * 0.9f * (1f - airW * 0.5f) + rollR * (1f - seatW), 0, -tgt[HumanRig.ULegR].z * 0.5f);
        if (seatW > 0.5f || kneelW > 0.5f) { tgt[HumanRig.FootL].x *= 0.5f; tgt[HumanRig.FootR].x *= 0.5f; }

        // ---------------- КОРПУС ----------------
        float breathe = Mathf.Sin(time * 1.6f) * (1.2f + run * 1.5f);
        tgt[HumanRig.Spine].x += 3f * move + 12f * run + 10f * sprintW + hunch * 0.5f + woundW * 10f;
        tgt[HumanRig.Chest].x += breathe + 4f * run + hunch * 0.5f + woundW * 6f;
        // плечи качаются против таза
        tgt[HumanRig.Spine].y += -s * 7f * stepAmt * (1f - aimW * 0.7f) - hipsYawCur * 0.55f;
        tgt[HumanRig.Chest].y += -s * 5f * stepAmt * (1f - aimW * 0.7f) - hipsYawCur * 0.45f;
        tgt[HumanRig.Spine].z += -c * 2.5f * stepAmt - bank * 0.3f;
        // наклон к цели и поворот к ней
        Vector3 la = transform.InverseTransformDirection(aimDir.sqrMagnitude > 0.001f ? aimDir.normalized : transform.forward);
        float pitch = Mathf.Asin(Mathf.Clamp(la.y, -1f, 1f)) * Mathf.Rad2Deg;
        float yaw = Mathf.Clamp(Mathf.Atan2(la.x, la.z) * Mathf.Rad2Deg, -70f, 70f);
        float upperAim = gunW * (1f - seatW) * (1f - ropeW);
        tgt[HumanRig.Spine].x -= pitch * 0.2f * upperAim;
        tgt[HumanRig.Chest].x -= pitch * 0.25f * upperAim;
        tgt[HumanRig.Spine].y += yaw * 0.35f - 22f * stanceW * 0.5f;
        tgt[HumanRig.Chest].y += yaw * 0.35f - 22f * stanceW * 0.5f;
        tgt[HumanRig.Chest].y += -10f * sprintW * gunW;

        // ---------------- РУКИ (FK, без оружия) ----------------
        float armAmp = Mathf.Lerp(18f, 55f, run) * stepAmt;
        Vector3 aL = new Vector3(sL * armAmp, 0, -7f);
        Vector3 aR = new Vector3(sR * armAmp, 0, 7f);
        Vector3 eL = new Vector3(-(12f + 60f * run + 18f * Mathf.Max(0, -sL) * stepAmt), 0, 0);
        Vector3 eR = new Vector3(-(12f + 60f * run + 18f * Mathf.Max(0, -sR) * stepAmt), 0, 0);
        switch (style)
        {
            case AnimStyle.Zombie:
            {
                float sw = Mathf.Sin(time * 2.3f) * 8f;
                aL = new Vector3(-80f + sw, 8f, -10f); aR = new Vector3(-75f - sw, -8f, 10f);
                eL = new Vector3(-15f, 0, 0); eR = new Vector3(-25f, 0, 0);
                tgt[HumanRig.Spine].x += 12f; tgt[HumanRig.Head].z += 18f + Mathf.Sin(time * 1.1f) * 6f; tgt[HumanRig.Head].x += 10f;
                tgt[HumanRig.Chest].z += Mathf.Sin(phase) * 6f;
                break;
            }
            case AnimStyle.Shy:
                tgt[HumanRig.Spine].x += 22f; tgt[HumanRig.Chest].x += 18f; tgt[HumanRig.Neck].x += 15f;
                aL = new Vector3(sL * armAmp * 0.4f, 0, -4f); aR = new Vector3(sR * armAmp * 0.4f, 0, 4f);
                eL = eR = new Vector3(-8f, 0, 0);
                tgt[HumanRig.Chest].x += Mathf.Sin(time * 9f) * 2.5f * (handsOnFace ? 1f : 0.2f);
                break;
            case AnimStyle.ShyRage:
            {
                float fl = Mathf.Sin(phase) * 75f;
                aL = new Vector3(fl - 30f, 0, -25f); aR = new Vector3(-fl - 30f, 0, 25f);
                eL = new Vector3(-30f - Mathf.Max(0, -fl) * 0.5f, 0, 0); eR = new Vector3(-30f - Mathf.Max(0, fl) * 0.5f, 0, 0);
                tgt[HumanRig.Spine].x += 28f * Mathf.Clamp01(spd / 4f); tgt[HumanRig.Chest].x += 12f;
                tgt[HumanRig.Neck].x -= 25f; tgt[HumanRig.Head].x -= 15f;
                break;
            }
            case AnimStyle.Doctor:
                aL = new Vector3(-25f + sL * 6f * stepAmt, 0, -10f); aR = new Vector3(-28f + sR * 6f * stepAmt, 0, 10f);
                eL = new Vector3(-85f, -20f, 0); eR = new Vector3(-80f, 20f, 0);
                tgt[HumanRig.Head].x -= 5f;
                break;
            case AnimStyle.Old:
                tgt[HumanRig.Spine].x += 22f; tgt[HumanRig.Chest].x += 12f; tgt[HumanRig.Neck].x -= 10f;
                aL = new Vector3(-25f + sL * 10f * stepAmt, 0, -8f); aR = new Vector3(-25f + sR * 10f * stepAmt, 0, 8f);
                eL = eR = new Vector3(-35f, 0, 0);
                tgt[HumanRig.Head].y += Mathf.Sin(time * 0.7f) * 15f;
                break;
            case AnimStyle.Burning:
                aL = new Vector3(sL * armAmp * 0.6f - 10f, 0, -28f); aR = new Vector3(sR * armAmp * 0.6f - 10f, 0, 28f);
                eL = eR = new Vector3(-40f, 0, 0);
                break;
        }
        // удар рукой (SCP, зомби)
        if (attackW > 0.001f)
        {
            float a = Mathf.Clamp01(attack01);
            float wind = Mathf.Sin(Mathf.Min(1f, a / 0.35f) * Mathf.PI * 0.5f);
            float strike = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(0.35f, 0.6f, a));
            aR = Vector3.Lerp(aR, Vector3.Lerp(new Vector3(-150f * wind, 0, 40f * wind), new Vector3(-40f, 0, -10f), strike), attackW);
            aL = Vector3.Lerp(aL, Vector3.Lerp(new Vector3(-60f * wind, 0, -20f), new Vector3(-110f, 0, -15f), strike), attackW * 0.6f);
            eR = Vector3.Lerp(eR, new Vector3(-80f * (1f - strike) - 10f, 0, 0), attackW);
            tgt[HumanRig.Spine].x += 12f * strike * attackW;
            tgt[HumanRig.Chest].y += (-25f * wind + 35f * strike) * attackW;
            hipsOff.z += 0.06f * strike * attackW;
        }
        // сидение без оружия — руки на коленях
        if (seatW > 0.001f && gunW < 0.5f)
        {
            aL = Vector3.Lerp(aL, new Vector3(-45f, 0, -5f), seatW); aR = Vector3.Lerp(aR, new Vector3(-45f, 0, 5f), seatW);
            eL = Vector3.Lerp(eL, new Vector3(-35f, 0, 0), seatW); eR = Vector3.Lerp(eR, new Vector3(-35f, 0, 0), seatW);
        }
        // падение — руки обмякают
        if (deathW > 0.001f)
        {
            aL = Vector3.Lerp(aL, new Vector3(-20f, 0, -15f), deathW); aR = Vector3.Lerp(aR, new Vector3(-25f, 0, 15f), deathW);
            eL = Vector3.Lerp(eL, new Vector3(-20f, 0, 0), deathW); eR = Vector3.Lerp(eR, new Vector3(-30f, 0, 0), deathW);
        }
        tgt[HumanRig.UArmL] = aL; tgt[HumanRig.UArmR] = aR;
        tgt[HumanRig.LArmL] = eL; tgt[HumanRig.LArmR] = eR;
        tgt[HumanRig.HandL] = new Vector3(-5f, 0, 0); tgt[HumanRig.HandR] = new Vector3(-5f, 0, 0);

        // ---------------- ГОЛОВА ----------------
        // компенсирует наклон корпуса и раскачку, смотрит на цель; в покое — осматривается
        float lookYaw = yaw * 0.25f, lookPitch = -pitch * 0.5f;
        if (idleAct == 0) { lookYaw += Mathf.Sin(idleT * Mathf.PI * 2f) * 55f * idleW; lookPitch += -5f * idleW; }
        if (idleAct == 4) { tgt[HumanRig.Head].z += Mathf.Sin(idleT * Mathf.PI * 2f) * 22f * idleW; tgt[HumanRig.Neck].x += 10f * idleW; }
        if (seatW > 0.5f) lookYaw += Mathf.Sin(time * 0.25f) * 35f;
        tgt[HumanRig.Neck].x -= (tgt[HumanRig.Spine].x + tgt[HumanRig.Chest].x) * 0.35f;
        tgt[HumanRig.Head].x += -(tgt[HumanRig.Spine].x + tgt[HumanRig.Chest].x) * 0.3f + lookPitch - Mathf.Abs(s) * 2f * stepAmt;
        tgt[HumanRig.Head].y += lookYaw - (tgt[HumanRig.Spine].y + tgt[HumanRig.Chest].y) * 0.3f;
        tgt[HumanRig.Head].z -= tgt[HumanRig.Hips].z * 0.5f;
        tgt[HumanRig.Head].x = Mathf.Clamp(tgt[HumanRig.Head].x, -40f, 45f);
        tgt[HumanRig.Head].y = Mathf.Clamp(tgt[HumanRig.Head].y, -70f, 70f);
        if (rig.jaw != null) rig.jaw.localRotation = Quaternion.Euler(Mathf.Lerp(0, 40f, mouth), 0, 0);
        // поправить шлем / сменить вес — немного корпуса
        if (idleAct == 3) { hipsOff.x += 0.05f * idleW; tgt[HumanRig.Hips].z += 6f * idleW; tgt[HumanRig.LLegL].x += 15f * idleW; }
        if (idleAct == 1) { tgt[HumanRig.Head].x += 22f * idleW; tgt[HumanRig.Head].y += 10f * idleW; }

        // реакции на попадания
        for (int i = 0; i < HumanRig.Count; i++) tgt[i] += react[i];
        hipsOff += hipsReact;

        // ---------------- применение со сглаживанием ----------------
        for (int i = 0; i < HumanRig.Count; i++)
        {
            Quaternion q = Quaternion.Euler(tgt[i]);
            float k = i >= HumanRig.ULegL ? 22f : i == HumanRig.Head || i == HumanRig.Neck ? 12f : 14f;
            if (deathW > 0.5f) k = 18f;
            cur[i] = Quaternion.Slerp(cur[i], q, 1f - Mathf.Exp(-k * dt));
            rig.b[i].localRotation = cur[i];
        }
        Vector3 hipsTarget = rig.hipsRest + hipsOff;
        hipsCur = Vector3.Lerp(hipsCur, hipsTarget, 1f - Mathf.Exp(-14f * dt));
        rig.b[HumanRig.Hips].localPosition = hipsCur;

        // вставание из позы трупа
        if (snapW > 0.001f)
        {
            float w = Mathf.SmoothStep(0, 1, snapW);
            for (int i = 0; i < HumanRig.Count; i++) rig.b[i].localRotation = Quaternion.Slerp(rig.b[i].localRotation, snap[i], w);
            rig.b[HumanRig.Hips].localPosition = Vector3.Lerp(rig.b[HumanRig.Hips].localPosition, snapHips, w);
            snapW -= dt / Mathf.Max(0.1f, snapDur);
        }

        // ---------------- IK ног по земле ----------------
        if (footIK && free > 0.5f && snapW <= 0.001f) FootIK(dt, stepAmt);

        // ---------------- ОРУЖИЕ и IK рук ----------------
        PlaceGun(dt, time, idleW, pistol);
        SolveArms(dt, time, idleW, pistol);
    }

    // Ступни стоят на земле даже на склонах: таз опускается, ноги сгибаются по IK
    void FootIK(float dt, float stepAmt)
    {
        var cam = Camera.main;
        if (cam == null || (cam.transform.position - transform.position).sqrMagnitude > 1600f) { footDropL = footDropR = hipsDrop = 0; return; }
        float baseY = transform.position.y;
        float scale = transform.lossyScale.y;
        float ankle = rig.b[HumanRig.FootL].localPosition.magnitude > 0 ? 0.075f * scale : 0.075f;
        float GroundAt(Vector3 p)
        {
            if (Physics.Raycast(p + Vector3.up * 0.6f, Vector3.down, out var h, 1.4f, 1 << Layers.World, QueryTriggerInteraction.Ignore)) return h.point.y - baseY;
            return 0f;
        }
        Vector3 fl = rig.b[HumanRig.FootL].position, fr = rig.b[HumanRig.FootR].position;
        float gl = Mathf.Clamp(GroundAt(fl), -0.4f, 0.4f), gr = Mathf.Clamp(GroundAt(fr), -0.4f, 0.4f);
        footDropL = Damp(footDropL, gl, 14f, dt);
        footDropR = Damp(footDropR, gr, 14f, dt);
        hipsDrop = Damp(hipsDrop, Mathf.Min(0f, Mathf.Min(footDropL, footDropR)), 10f, dt);
        if (Mathf.Abs(footDropL) < 0.01f && Mathf.Abs(footDropR) < 0.01f && Mathf.Abs(hipsDrop) < 0.01f) return;
        var hips = rig.b[HumanRig.Hips];
        hips.position += Vector3.up * hipsDrop;
        LegIK(HumanRig.ULegL, fl.y - baseY, footDropL, ankle);
        LegIK(HumanRig.ULegR, fr.y - baseY, footDropR, ankle);
    }

    void LegIK(int upper, float footY, float ground, float ankle)
    {
        var u = rig.b[upper]; var l = rig.b[upper + 1]; var f = rig.b[upper + 2];
        // поднимаем стопу ровно на высоту земли (с учётом текущего подъёма в шаге)
        float lift = Mathf.Max(0f, footY - ankle);
        Vector3 target = f.position;
        target.y = transform.position.y + ground + ankle + lift;
        Quaternion fRot = f.rotation;
        Vector3 pole = l.position + transform.forward * 0.6f;
        TwoBone(u, l, f, target, pole, 1f, true);
        f.rotation = fRot;
    }

    void PlaceGun(float dt, float time, float idleW, bool pistol)
    {
        if (gun == null) return;
        var t = gun.transform;
        bool rpg = gun.def.id == "rpg";
        Transform chest = rig.b[HumanRig.Chest];
        float tor = rig.shape.torso;
        Vector3 pivotLocal = pistol ? new Vector3(0.0f, 0.15f * tor, 0.05f) : rpg ? new Vector3(0.12f, 0.27f * tor, 0.0f) : new Vector3(0.1f, 0.16f * tor, 0.03f);
        if (rig.shape.model) pivotLocal += new Vector3(0.02f, 0.02f, 0.06f);
        pivotPos = Vector3.Lerp(pivotPos, pivotLocal, 1f - Mathf.Exp(-8f * dt));
        rig.aimPivot.localPosition = pivotPos;

        Vector3 ad = aimDir.sqrMagnitude > 0.001f ? aimDir.normalized : transform.forward;
        Quaternion aimRot = Quaternion.LookRotation(ad, Vector3.up);
        Quaternion lowRot = transform.rotation * Quaternion.Euler(30f, -28f, 8f);
        if (pistol) lowRot = transform.rotation * Quaternion.Euler(50f, -5f, 0f);
        Quaternion sprintRot = transform.rotation * Quaternion.Euler(50f, -50f, 25f);
        Quaternion seatRot = transform.rotation * Quaternion.Euler(-75f, 5f, 0f);
        Quaternion ropeRot = chest.rotation * Quaternion.Euler(-80f, 0f, 40f);

        Quaternion target = Quaternion.Slerp(lowRot, aimRot, aimW);
        target = Quaternion.Slerp(target, sprintRot, sprintW * (1f - aimW));
        // перезарядка — оружие наклоняется к себе
        if (reloadW > 0.001f)
        {
            float r = Mathf.Clamp01(reload01);
            float tilt = Mathf.Sin(Mathf.Min(1f, r * 1.2f) * Mathf.PI);
            Quaternion rr = gun.def.kind == WeaponKind.Shotgun ? transform.rotation * Quaternion.Euler(10f, -25f, -45f) : transform.rotation * Quaternion.Euler(25f, -20f, 35f);
            target = Quaternion.Slerp(target, rr, reloadW * (0.25f + 0.75f * tilt));
        }
        if (throwW > 0.001f) target = Quaternion.Slerp(target, lowRot * Quaternion.Euler(20f, -20f, 0), throwW);
        // проверка оружия в покое: поворачивает его к себе
        if (idleAct == 1) target = Quaternion.Slerp(target, transform.rotation * Quaternion.Euler(10f, -50f, -50f), idleW);
        // удар прикладом
        if (meleeW > 0.001f)
        {
            float m = Mathf.Clamp01(melee01);
            float wind = S01(0f, 0.3f, m) * (1f - S01(0.3f, 0.45f, m));
            float hit = S01(0.3f, 0.45f, m) * (1f - S01(0.6f, 1f, m));
            target = Quaternion.Slerp(target, transform.rotation * Quaternion.Euler(-30f, 40f, 60f), wind * meleeW);
            target = Quaternion.Slerp(target, transform.rotation * Quaternion.Euler(-10f, -40f, 80f), hit * meleeW);
        }
        target = Quaternion.Slerp(target, seatRot, seatW);
        float bob = Mathf.Sin(phase * 2f) * 1.5f * Mathf.Clamp01(spd / 3f);
        target = target * Quaternion.Euler(bob + kick.x + Mathf.Sin(time * 1.3f) * 0.6f, Mathf.Sin(phase) * 1.2f * Mathf.Clamp01(spd / 3f), 0);
        pivotRot = Quaternion.Slerp(pivotRot, target, 1f - Mathf.Exp(-(aiming ? 18f : 10f) * dt));
        Quaternion final = Quaternion.Slerp(pivotRot, ropeRot, 1f - gunW);

        Vector3 holdOffset = pistol ? new Vector3(0f, -0.02f, Mathf.Lerp(0.28f, 0.42f, aimW)) : rpg ? new Vector3(0f, -0.08f, 0.05f) : new Vector3(0f, -0.03f, 0.2f + kick.z * 0.02f);
        if (meleeW > 0.001f) holdOffset += new Vector3(0, 0.05f, 0.15f) * S01(0.3f, 0.45f, Mathf.Clamp01(melee01)) * (1f - S01(0.6f, 1f, Mathf.Clamp01(melee01)));
        Vector3 holdPos = rig.aimPivot.position + final * holdOffset * transform.lossyScale.y;
        Vector3 slingPos = chest.TransformPoint(new Vector3(0.05f, 0.12f * tor, -0.22f));
        float g = gunW;
        t.position = Vector3.Lerp(slingPos, holdPos, g);
        t.rotation = final;
        // падающий боец роняет оружие из рук (IK отпускает), а саму модель роняет Soldier
    }

    void SolveArms(float dt, float time, float idleW, bool pistol)
    {
        var b = rig.b;
        float ikR = 0, ikL = 0;
        Vector3 tR = Vector3.zero, tL = Vector3.zero;
        Quaternion rR = Quaternion.identity, rL = Quaternion.identity;
        Vector3 right = transform.right, down = -transform.up, back = -transform.forward, fwdW = transform.forward;
        float sc = transform.lossyScale.y;
        Transform chest = b[HumanRig.Chest];

        if (gun != null && gunW > 0.01f)
        {
            var gt = gun.transform;
            rR = HandPose.Grip(gt.rotation);
            tR = HandPose.Wrist(gun.grip.position + gt.right * 0.022f * sc, rR, sc);
            ikR = gunW * (1f - throwW);
            rL = pistol ? HandPose.Grip(gt.rotation) * Quaternion.Euler(0, 160, 0) : HandPose.Support(gt.rotation);
            Vector3 forePalm = pistol ? gun.grip.position - gt.right * 0.03f * sc : gun.foregrip.position - gt.up * 0.025f * sc;
            Vector3 fore = HandPose.Wrist(forePalm, rL, sc);
            tL = fore;
            ikL = gunW;
            // ---- перезарядка ----
            if (reloadW > 0.01f)
            {
                float r = Mathf.Clamp01(reload01);
                Vector3 pouch = b[HumanRig.Hips].TransformPoint(new Vector3(-0.16f, 0.06f, 0.13f));
                Quaternion holdQ = HandPose.Hold(chest.rotation, 0.5f);
                Vector3 p; Quaternion q = rL;
                if (gun.def.kind == WeaponKind.Shotgun)
                {
                    // по патрону: из подсумка в окно снизу
                    Vector3 port = gt.TransformPoint(new Vector3(0, -0.01f, 0.1f));
                    float k = Mathf.Sin(shellPhase * Mathf.PI);
                    p = Vector3.Lerp(HandPose.Wrist(port, holdQ, sc), HandPose.Wrist(pouch, holdQ, sc), k);
                    q = holdQ;
                }
                else if (gun.def.id == "rpg")
                {
                    Vector3 back2 = chest.TransformPoint(new Vector3(-0.2f, 0.1f, -0.2f));
                    Vector3 muz = gun.muzzle.position + gt.forward * 0.15f * sc;
                    if (r < 0.35f) p = Vector3.Lerp(fore, back2, S01(0f, 0.35f, r));
                    else if (r < 0.75f) p = Vector3.Lerp(back2, muz, S01(0.35f, 0.75f, r));
                    else p = Vector3.Lerp(muz, fore, S01(0.75f, 1f, r));
                    q = Quaternion.Slerp(rL, holdQ, Bell(0f, 1f, r));
                    if (gun.mag != null) gun.mag.gameObject.SetActive(r < 0.25f || r > 0.6f);
                }
                else
                {
                    Vector3 magPos = gt.TransformPoint(gun.magRest);
                    Vector3 magW = HandPose.Wrist(magPos - gt.up * 0.04f * sc, holdQ, sc);
                    Vector3 bolt = gt.TransformPoint(gun.def.id == "ak" || gun.def.id == "svd" || gun.def.id == "saiga" ? new Vector3(0.05f, 0.07f, 0.15f) : new Vector3(0f, 0.09f, -0.08f));
                    if (r < 0.15f) p = Vector3.Lerp(fore, magW, S01(0f, 0.15f, r));
                    else if (r < 0.4f) p = Vector3.Lerp(magW, HandPose.Wrist(pouch, holdQ, sc), S01(0.15f, 0.4f, r));
                    else if (r < 0.65f) p = Vector3.Lerp(HandPose.Wrist(pouch, holdQ, sc), magW, S01(0.4f, 0.65f, r));
                    else if (reloadEmpty && r < 0.85f) p = Vector3.Lerp(magW, HandPose.Wrist(bolt, holdQ, sc), Bell(0.65f, 0.85f, r) > 0 ? S01(0.65f, 0.72f, r) * (1f - S01(0.78f, 0.85f, r)) : 0f);
                    else p = Vector3.Lerp(magW, fore, S01(reloadEmpty ? 0.8f : 0.65f, 0.95f, r));
                    q = r > 0.05f && r < 0.9f ? holdQ : rL;
                    // магазин в руке
                    if (gun.mag != null)
                    {
                        if (r > 0.15f && r < 0.62f) gun.mag.position = b[HumanRig.HandL].position + b[HumanRig.HandL].rotation * new Vector3(0, -0.08f, 0) * sc;
                        else gun.mag.localPosition = gun.magRest;
                    }
                }
                tL = Vector3.Lerp(fore, p, reloadW);
                rL = Quaternion.Slerp(rL, q, reloadW);
                if (gun.pump != null && gun.def.kind == WeaponKind.Shotgun) gun.pump.localPosition = gun.pumpRest + new Vector3(0, 0, -0.08f * S01(0.9f, 0.95f, r) * (1f - S01(0.95f, 1f, r)));
            }
            else
            {
                if (gun.mag != null && gun.mag.localPosition != gun.magRest) gun.mag.localPosition = gun.magRest;
                if (gun.mag != null && !gun.mag.gameObject.activeSelf) gun.mag.gameObject.SetActive(true);
            }
            // ---- бездействие: поправить шлем, постучать по магазину ----
            if (idleAct == 2 && idleW > 0.01f)
            {
                Vector3 helm = b[HumanRig.Head].TransformPoint(new Vector3(-0.1f, 0.24f, 0.08f));
                tL = Vector3.Lerp(tL, helm, idleW); rL = Quaternion.Slerp(rL, b[HumanRig.Head].rotation * Quaternion.Euler(180f, 0, -60f), idleW);
            }
            if (idleAct == 5 && idleW > 0.01f && gun.mag != null)
            {
                Vector3 mg = gun.mag.position - gt.up * (0.1f + Mathf.Abs(Mathf.Sin(idleT * 25f)) * 0.03f) * sc;
                tL = Vector3.Lerp(tL, mg, idleW);
            }
            // ---- граната: обе руки вместе (чека), замах, бросок ----
            if (throwW > 0.01f)
            {
                float a = Mathf.Clamp01(throw01);
                Vector3 chestF = chest.TransformPoint(new Vector3(0.02f, 0.05f, 0.35f));
                Vector3 wind = chest.TransformPoint(new Vector3(0.3f, 0.35f, -0.15f));
                Vector3 rel = chest.TransformPoint(new Vector3(0.05f, 0.45f, 0.55f));
                Vector3 p = a < 0.25f ? Vector3.Lerp(tR, chestF, S01(0f, 0.25f, a))
                    : a < 0.45f ? Vector3.Lerp(chestF, wind, S01(0.3f, 0.45f, a))
                    : a < 0.6f ? Vector3.Lerp(wind, rel, S01(0.45f, 0.6f, a))
                    : Vector3.Lerp(rel, tR, S01(0.65f, 1f, a));
                tR = p; ikR = Mathf.Max(ikR, throwW);
                rR = HandPose.Hold(chest.rotation, a > 0.45f && a < 0.6f ? -0.5f : 0.2f) * Quaternion.Euler(0, 180, 0);
                // левая рука выдёргивает чеку
                if (a < 0.35f)
                {
                    float k = Bell(0.05f, 0.35f, a);
                    tL = Vector3.Lerp(tL, chestF + right * (0.05f - 0.1f * S01(0.18f, 0.28f, a)) * sc, k);
                    rL = Quaternion.Slerp(rL, HandPose.Hold(chest.rotation, 0.3f), k);
                }
            }
        }
        // ---- канат: перехват руками ----
        if (ropeW > 0.01f)
        {
            float hh = Mathf.Sin(time * 8f) * 0.08f;
            Vector3 top = new Vector3(ropePoint.x, b[HumanRig.Head].position.y + 0.2f, ropePoint.z);
            tR = Vector3.Lerp(tR, top + Vector3.up * (0.1f + hh), ropeW); ikR = Mathf.Max(ikR, ropeW);
            tL = Vector3.Lerp(tL, top + Vector3.up * (-0.15f - hh), ropeW); ikL = Mathf.Max(ikL, ropeW);
            rR = Quaternion.Slerp(rR, transform.rotation * Quaternion.Euler(180f, 0, 0), ropeW);
            rL = Quaternion.Slerp(rL, transform.rotation * Quaternion.Euler(180f, 0, 0), ropeW);
        }
        // ---- руки на лице (SCP-096) ----
        if (faceW > 0.01f)
        {
            var h = b[HumanRig.Head];
            Vector3 f = h.TransformPoint(new Vector3(0, 0.12f, 0.2f));
            tR = Vector3.Lerp(tR, f + h.right * 0.05f, faceW); ikR = Mathf.Max(ikR, faceW);
            tL = Vector3.Lerp(tL, f - h.right * 0.05f, faceW); ikL = Mathf.Max(ikL, faceW);
            rR = h.rotation * Quaternion.Euler(170f, 0, 15f);
            rL = h.rotation * Quaternion.Euler(170f, 0, -15f);
        }
        // ---- жесты командира (левая рука) ----
        if (signalT >= 0)
        {
            float k = S01(0f, 0.15f, signalT) * (1f - S01(0.85f, 1f, signalT));
            Vector3 p; Quaternion q;
            switch (signal)
            {
                case Signal.Point:
                    p = chest.TransformPoint(new Vector3(-0.15f, 0.3f, 0.65f)); q = transform.rotation * Quaternion.Euler(-90f, 0, 0); break;
                case Signal.MoveUp:
                {
                    float w = Mathf.Sin(signalT * Mathf.PI * 4f);
                    p = chest.TransformPoint(new Vector3(-0.25f, 0.55f + w * 0.12f, 0.15f + w * 0.25f)); q = transform.rotation * Quaternion.Euler(-160f + w * 40f, 0, 0); break;
                }
                case Signal.Hold:
                    p = chest.TransformPoint(new Vector3(-0.28f, 0.6f, 0.05f)); q = transform.rotation * Quaternion.Euler(180f, 0, 0); break;
                default:
                {
                    float a = signalT * Mathf.PI * 6f;
                    p = chest.TransformPoint(new Vector3(-0.15f + Mathf.Cos(a) * 0.15f, 0.75f, Mathf.Sin(a) * 0.15f)); q = transform.rotation * Quaternion.Euler(180f, 0, 0); break;
                }
            }
            tL = Vector3.Lerp(tL, p, k); rL = Quaternion.Slerp(rL, q, k); ikL = Mathf.Max(ikL, k);
        }
        // ---- ранен: рука прижата к боку ----
        if (woundW > 0.3f && reloadW < 0.1f && throwW < 0.1f && aimW < 0.5f && gun != null && signalT < 0)
        {
            Vector3 sidep = b[HumanRig.Spine].TransformPoint(new Vector3(-0.18f, 0.05f, 0.08f));
            float k = (woundW - 0.3f) / 0.7f;
            tL = Vector3.Lerp(tL, sidep, k); rL = Quaternion.Slerp(rL, b[HumanRig.Spine].rotation * Quaternion.Euler(0, 0, -100f), k);
        }

        if (ikR > 0.01f)
        {
            Vector3 pole = b[HumanRig.UArmR].position + (down * 0.6f + right * 0.45f + back * 0.2f) * sc;
            TwoBone(b[HumanRig.UArmR], b[HumanRig.LArmR], b[HumanRig.HandR], tR, pole, ikR);
            b[HumanRig.HandR].rotation = Quaternion.Slerp(b[HumanRig.HandR].rotation, rR, ikR);
        }
        if (ikL > 0.01f)
        {
            Vector3 pole = b[HumanRig.UArmL].position + (down * 0.65f - right * 0.4f + back * 0.1f) * sc;
            TwoBone(b[HumanRig.UArmL], b[HumanRig.LArmL], b[HumanRig.HandL], tL, pole, ikL);
            b[HumanRig.HandL].rotation = Quaternion.Slerp(b[HumanRig.HandL].rotation, rL, ikL);
        }
    }

    // Аналитический IK двух звеньев. Кость направлена по -Y.
    // Руки: сгиб вперёд (локоть уходит к полюсу, кисть — от него). Ноги (legs = true): колено — к полюсу.
    public static void TwoBone(Transform a, Transform b, Transform c, Vector3 target, Vector3 pole, float w, bool legs = false)
    {
        Vector3 A = a.position;
        float l1 = Vector3.Distance(A, b.position);
        float l2 = Vector3.Distance(b.position, c.position);
        Vector3 d = target - A;
        float dist = Mathf.Clamp(d.magnitude, 0.01f, (l1 + l2) * 0.999f);
        Vector3 dn = d.sqrMagnitude > 1e-6f ? d.normalized : -a.up;
        float cosA = Mathf.Clamp((l1 * l1 + dist * dist - l2 * l2) / (2f * l1 * dist), -1f, 1f);
        float sinA = Mathf.Sqrt(1f - cosA * cosA);
        Vector3 pd = pole - A;
        Vector3 perp = pd - Vector3.Dot(pd, dn) * dn;
        if (perp.sqrMagnitude < 1e-6f) perp = Vector3.Cross(dn, a.right);
        perp.Normalize();
        Vector3 elbow = A + dn * (l1 * cosA) + perp * (l1 * sinA);
        Vector3 hand = A + dn * dist;
        Vector3 fwdHint = legs ? perp : -perp;
        Vector3 up1 = (A - elbow).normalized;
        Vector3 f1 = Vector3.ProjectOnPlane(fwdHint, up1);
        if (f1.sqrMagnitude < 1e-6f) f1 = a.forward;
        Quaternion qa = Quaternion.LookRotation(f1.normalized, up1);
        Vector3 up2 = (elbow - hand).normalized;
        Vector3 f2 = Vector3.ProjectOnPlane(fwdHint, up2);
        if (f2.sqrMagnitude < 1e-6f) f2 = b.forward;
        Quaternion qb = Quaternion.LookRotation(f2.normalized, up2);
        Quaternion cRot = c.rotation;
        a.rotation = Quaternion.Slerp(a.rotation, qa, w);
        b.rotation = Quaternion.Slerp(b.rotation, qb, w);
        c.rotation = cRot;
    }
}
