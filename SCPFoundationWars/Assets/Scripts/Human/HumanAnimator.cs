using UnityEngine;

public enum AnimStyle { Soldier, Zombie, Shy, ShyRage, Doctor, Old, Burning }

// Процедурная анимация человека. Все состояния (покой, ходьба, бег, присед, прицеливание, перезарядка,
// бросок гранаты, сидение в вертолёте, спуск по канату, прыжок, удар) смешиваются весами,
// а итоговая поза каждой кости догоняет целевую с критическим демпфированием — переходы всегда плавные.
[DefaultExecutionOrder(100)]
public class HumanAnimator : MonoBehaviour
{
    public HumanRig rig;
    public AnimStyle style = AnimStyle.Soldier;

    // ---- входные параметры (выставляет ИИ / контроллер) ----
    public Vector3 velocity;
    public Vector3 aimDir = Vector3.forward;
    public bool aiming, crouch, sprint, seated, onRope, airborne, slung, handsOnFace, kneel;
    public float reload01 = -1f, throw01 = -1f, attack01 = -1f;
    public float mouth;                // 0..1 открытие рта (096)
    public float hunch;                // дополнительная сутулость
    public GunModel gun;
    public Vector3 ropePoint;          // точка каната для рук
    public float speedMul = 1f;
    public bool footsteps = true;

    // ---- внутреннее состояние ----
    float phase, spd;
    Vector2 moveDir = new Vector2(0, 1);
    float crouchW, aimW, seatW, ropeW, airW, sprintW, gunW = 1f, faceW, kneelW, landW, reloadW, throwW, attackW;
    readonly Quaternion[] cur = new Quaternion[HumanRig.Count];
    readonly Vector3[] tgt = new Vector3[HumanRig.Count];
    Vector3 hipsCur;
    bool init;
    Quaternion pivotRot = Quaternion.identity;
    Vector3 pivotPos;
    Vector3 kick;     // отдача: x — подброс, z — назад
    Vector3 kickVel;
    Vector3 flinch;   // реакция на попадание (локальный поворот корпуса)
    float snapW;      // смешивание из позы "лёжа" (вставание)
    float snapDur = 1f;
    readonly Quaternion[] snap = new Quaternion[HumanRig.Count];
    Vector3 snapHips;
    float stepTimer;
    float t0;

    public float Phase => phase;

    void Start()
    {
        t0 = Random.Range(0f, 100f);
    }

    void InitPose()
    {
        for (int i = 0; i < HumanRig.Count; i++) cur[i] = rig.b[i].localRotation;
        hipsCur = rig.b[HumanRig.Hips].localPosition;
        pivotPos = rig.aimPivot.localPosition;
        init = true;
    }

    public void Kick(float up, float back)
    {
        kickVel += new Vector3(-up * 60f, 0, -back * 3f);
    }

    public void Flinch(Vector3 worldDir, float amount)
    {
        Vector3 l = transform.InverseTransformDirection(worldDir);
        flinch += new Vector3(l.z * 25f, -l.x * 10f, -l.x * 22f) * amount;
        flinch = Vector3.ClampMagnitude(flinch, 45f);
    }

    // Запомнить текущую (физическую) позу и плавно перейти из неё в анимацию
    public void BlendFromCurrent(float duration)
    {
        if (!init) InitPose();
        for (int i = 0; i < HumanRig.Count; i++) { snap[i] = rig.b[i].localRotation; cur[i] = snap[i]; }
        snapHips = rig.b[HumanRig.Hips].localPosition;
        hipsCur = snapHips;
        snapW = 1f;
        snapDur = duration;
    }

    // Мгновенно встать в целевую позу (после телепорта, без смешивания)
    public void Snap() { init = false; }

    static float Damp(float a, float b, float k, float dt) => Mathf.Lerp(a, b, 1f - Mathf.Exp(-k * dt));

    void LateUpdate()
    {
        if (rig == null) return;
        if (!init) InitPose();
        float dt = Mathf.Min(Time.deltaTime, 0.05f);
        if (dt <= 0) return;
        float time = Time.time + t0;

        // ---- веса состояний ----
        Vector3 lv = transform.InverseTransformDirection(velocity);
        lv.y = 0;
        float rawSpd = lv.magnitude;
        spd = Damp(spd, rawSpd, 8f, dt);
        if (rawSpd > 0.2f) moveDir = Vector2.Lerp(moveDir, new Vector2(lv.x, lv.z) / rawSpd, 1f - Mathf.Exp(-10f * dt));
        bool hasGun = gun != null && style == AnimStyle.Soldier;

        crouchW = Damp(crouchW, crouch && !seated && !onRope ? 1f : 0f, 7f, dt);
        aimW = Damp(aimW, aiming && hasGun && !sprint ? 1f : 0f, 9f, dt);
        sprintW = Damp(sprintW, sprint && rawSpd > 3f ? 1f : 0f, 6f, dt);
        seatW = Damp(seatW, seated ? 1f : 0f, 5f, dt);
        ropeW = Damp(ropeW, onRope ? 1f : 0f, 8f, dt);
        bool wasAir = airW > 0.5f;
        airW = Damp(airW, airborne ? 1f : 0f, 9f, dt);
        if (wasAir && !airborne) landW = 1f;
        landW = Damp(landW, 0f, 3.5f, dt);
        gunW = Damp(gunW, hasGun && !slung && !onRope ? 1f : 0f, 6f, dt);
        faceW = Damp(faceW, handsOnFace ? 1f : 0f, 4f, dt);
        kneelW = Damp(kneelW, kneel ? 1f : 0f, 4f, dt);
        reloadW = Damp(reloadW, reload01 >= 0 ? 1f : 0f, 10f, dt);
        throwW = Damp(throwW, throw01 >= 0 ? 1f : 0f, 14f, dt);
        attackW = Damp(attackW, attack01 >= 0 ? 1f : 0f, 14f, dt);

        // отдача (пружина)
        kickVel += (-kick * 220f - kickVel * 22f) * dt;
        kick += kickVel * dt;
        flinch = Vector3.Lerp(flinch, Vector3.zero, 1f - Mathf.Exp(-6f * dt));

        float scaleK = transform.lossyScale.y;
        float legLen = (rig.shape.legU + rig.shape.legL) * scaleK;
        float move = Mathf.Clamp01(spd / (1.0f * scaleK)) * (1f - seatW) * (1f - ropeW) * (1f - airW);
        float run = Mathf.InverseLerp(3.2f * scaleK, 6.5f * scaleK, spd);
        float stride = Mathf.Lerp(1.15f, 2.3f, run) * legLen / 0.89f * (1f - crouchW * 0.35f);
        if (style == AnimStyle.ShyRage) stride *= 1.4f;
        float prevPhase = phase;
        phase += spd / Mathf.Max(0.3f, stride) * Mathf.PI * 2f * dt;
        if (phase > Mathf.PI * 1000f) phase -= Mathf.PI * 1000f;

        // шаги
        if (footsteps && move > 0.3f && Mathf.Floor(prevPhase / Mathf.PI) != Mathf.Floor(phase / Mathf.PI))
        {
            var cam = Camera.main;
            if (cam != null && (cam.transform.position - transform.position).sqrMagnitude < 900f)
                Sfx.Play("step", transform.position, 0.12f + run * 0.15f, Random.Range(0.85f, 1.15f), 25f);
        }

        float s = Mathf.Sin(phase), c = Mathf.Cos(phase);
        float fwd = moveDir.y, side = moveDir.x;
        for (int i = 0; i < HumanRig.Count; i++) tgt[i] = Vector3.zero;
        Vector3 hipsOff = Vector3.zero;

        // ---------------- НОГИ ----------------
        float amp = Mathf.Lerp(22f, 48f, run) * move;
        float kneeAmp = Mathf.Lerp(35f, 95f, run) * move;
        float limp = style == AnimStyle.Zombie ? 0.55f : 1f;
        float swingL = s * amp, swingR = -s * amp * limp;
        tgt[HumanRig.ULegL] = new Vector3(-swingL * fwd, 0, swingL * side * 0.55f);
        tgt[HumanRig.ULegR] = new Vector3(-swingR * fwd, 0, swingR * side * 0.55f);
        float kL = 4f + Mathf.Max(0, c) * kneeAmp + (fwd < 0 ? Mathf.Max(0, -c) * kneeAmp * 0.3f : 0);
        float kR = 4f + Mathf.Max(0, -c) * kneeAmp * limp + (fwd < 0 ? Mathf.Max(0, c) * kneeAmp * 0.3f : 0);
        if (run > 0.1f) { tgt[HumanRig.ULegL].x -= run * 10f; tgt[HumanRig.ULegR].x -= run * 10f; }
        tgt[HumanRig.LLegL] = new Vector3(kL, 0, 0);
        tgt[HumanRig.LLegR] = new Vector3(kR, 0, 0);
        hipsOff.y += (-Mathf.Abs(c) * (0.025f + run * 0.04f) + 0.02f) * move - run * 0.05f;
        tgt[HumanRig.Hips].y += s * 6f * move * fwd;
        tgt[HumanRig.Hips].z += c * 3f * move;

        // присед
        if (crouchW > 0.001f)
        {
            float cw = crouchW * (1f - seatW);
            tgt[HumanRig.ULegL] += new Vector3(-75f, 0, -4f) * cw;
            tgt[HumanRig.ULegR] += new Vector3(-55f, 0, 4f) * cw;
            tgt[HumanRig.LLegL] += new Vector3(105f, 0, 0) * cw;
            tgt[HumanRig.LLegR] += new Vector3(115f, 0, 0) * cw;
            hipsOff.y -= 0.36f * cw;
            hipsOff.z -= 0.08f * cw;
            tgt[HumanRig.Spine].x += 18f * cw;
        }
        // приземление — короткое пружинящее приседание
        if (landW > 0.01f)
        {
            tgt[HumanRig.ULegL].x -= 45f * landW; tgt[HumanRig.ULegR].x -= 40f * landW;
            tgt[HumanRig.LLegL].x += 75f * landW; tgt[HumanRig.LLegR].x += 70f * landW;
            hipsOff.y -= 0.25f * landW;
            tgt[HumanRig.Spine].x += 15f * landW;
        }
        // полёт (прыжок из вертолёта)
        if (airW > 0.001f)
        {
            tgt[HumanRig.ULegL] += new Vector3(-50f, 0, -5f) * airW;
            tgt[HumanRig.ULegR] += new Vector3(-20f, 0, 5f) * airW;
            tgt[HumanRig.LLegL] += new Vector3(70f, 0, 0) * airW;
            tgt[HumanRig.LLegR] += new Vector3(40f, 0, 0) * airW;
        }
        // сидение
        if (seatW > 0.001f)
        {
            for (int i = HumanRig.ULegL; i <= HumanRig.FootR; i++) tgt[i] *= 1f - seatW;
            tgt[HumanRig.ULegL] += new Vector3(-88f, 0, -6f) * seatW;
            tgt[HumanRig.ULegR] += new Vector3(-88f, 0, 6f) * seatW;
            tgt[HumanRig.LLegL] += new Vector3(80f + Mathf.Sin(time * 0.7f) * 3f, 0, 0) * seatW;
            tgt[HumanRig.LLegR] += new Vector3(85f, 0, 0) * seatW;
            hipsOff = Vector3.Lerp(hipsOff, new Vector3(0, -(rig.shape.legU + rig.shape.legL) + 0.42f, 0.02f), seatW);
            tgt[HumanRig.Spine].x += 4f * seatW;
        }
        // канат
        if (ropeW > 0.001f)
        {
            for (int i = HumanRig.ULegL; i <= HumanRig.FootR; i++) tgt[i] *= 1f - ropeW;
            tgt[HumanRig.ULegL] += new Vector3(-30f, 0, 8f) * ropeW;
            tgt[HumanRig.ULegR] += new Vector3(-15f, 0, -8f) * ropeW;
            tgt[HumanRig.LLegL] += new Vector3(45f, 0, 0) * ropeW;
            tgt[HumanRig.LLegR] += new Vector3(25f, 0, 0) * ropeW;
        }
        // колено (SCP-049 "оперирует")
        if (kneelW > 0.001f)
        {
            tgt[HumanRig.ULegL] = Vector3.Lerp(tgt[HumanRig.ULegL], new Vector3(-90f, 0, 0), kneelW);
            tgt[HumanRig.LLegL] = Vector3.Lerp(tgt[HumanRig.LLegL], new Vector3(90f, 0, 0), kneelW);
            tgt[HumanRig.ULegR] = Vector3.Lerp(tgt[HumanRig.ULegR], new Vector3(5f, 0, 0), kneelW);
            tgt[HumanRig.LLegR] = Vector3.Lerp(tgt[HumanRig.LLegR], new Vector3(95f, 0, 0), kneelW);
            hipsOff = Vector3.Lerp(hipsOff, new Vector3(0, -rig.shape.legL + 0.02f, -0.15f), kneelW);
            tgt[HumanRig.Spine].x += 25f * kneelW;
        }
        // стопы — параллельно земле
        tgt[HumanRig.FootL] = new Vector3(-(tgt[HumanRig.ULegL].x + tgt[HumanRig.LLegL].x) * 0.85f * (1f - airW * 0.5f), 0, 0);
        tgt[HumanRig.FootR] = new Vector3(-(tgt[HumanRig.ULegR].x + tgt[HumanRig.LLegR].x) * 0.85f * (1f - airW * 0.5f), 0, 0);
        if (seatW > 0.5f || kneelW > 0.5f) { tgt[HumanRig.FootL].x *= 0.5f; tgt[HumanRig.FootR].x *= 0.5f; }

        // ---------------- КОРПУС ----------------
        float breathe = Mathf.Sin(time * 1.6f) * 1.2f;
        tgt[HumanRig.Spine].x += 3f * move + 12f * run + hunch * 0.5f;
        tgt[HumanRig.Chest].x += breathe + 4f * run + hunch * 0.5f;
        tgt[HumanRig.Spine].y += -s * 7f * move * (1f - aimW * 0.6f);
        tgt[HumanRig.Chest].y += -s * 5f * move * (1f - aimW * 0.6f);
        // наклон к цели (вверх/вниз) и поворот к ней
        Vector3 la = transform.InverseTransformDirection(aimDir.sqrMagnitude > 0.001f ? aimDir.normalized : transform.forward);
        float pitch = Mathf.Asin(Mathf.Clamp(la.y, -1f, 1f)) * Mathf.Rad2Deg;
        float yaw = Mathf.Atan2(la.x, la.z) * Mathf.Rad2Deg;
        yaw = Mathf.Clamp(yaw, -70f, 70f);
        float upperAim = gunW * (1f - seatW) * (1f - ropeW);
        tgt[HumanRig.Spine].x -= pitch * 0.2f * upperAim;
        tgt[HumanRig.Chest].x -= pitch * 0.25f * upperAim;
        tgt[HumanRig.Spine].y += yaw * 0.35f;
        tgt[HumanRig.Chest].y += yaw * 0.35f;
        // спринт с оружием — корпус чуть развёрнут
        tgt[HumanRig.Chest].y += -10f * sprintW * gunW;

        // ---------------- РУКИ (FK) ----------------
        float armAmp = Mathf.Lerp(18f, 55f, run) * move;
        Vector3 aL = new Vector3(s * armAmp, 0, -7f);
        Vector3 aR = new Vector3(-s * armAmp, 0, 7f);
        Vector3 eL = new Vector3(-(12f + 60f * run), 0, 0);
        Vector3 eR = eL;
        switch (style)
        {
            case AnimStyle.Zombie:
            {
                float sw = Mathf.Sin(time * 2.3f) * 8f;
                aL = new Vector3(-80f + sw, 8f, -10f); aR = new Vector3(-75f - sw, -8f, 10f);
                eL = new Vector3(-15f, 0, 0); eR = new Vector3(-25f, 0, 0);
                tgt[HumanRig.Spine].x += 12f; tgt[HumanRig.Head].z += 18f; tgt[HumanRig.Head].x += 10f;
                break;
            }
            case AnimStyle.Shy:
                tgt[HumanRig.Spine].x += 22f; tgt[HumanRig.Chest].x += 18f; tgt[HumanRig.Neck].x += 15f;
                aL = new Vector3(s * armAmp * 0.4f, 0, -4f); aR = new Vector3(-s * armAmp * 0.4f, 0, 4f);
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
                aL = new Vector3(-25f + s * 6f * move, 0, -10f); aR = new Vector3(-28f - s * 6f * move, 0, 10f);
                eL = new Vector3(-85f, -20f, 0); eR = new Vector3(-80f, 20f, 0);
                tgt[HumanRig.Head].x -= 5f;
                break;
            case AnimStyle.Old:
                tgt[HumanRig.Spine].x += 22f; tgt[HumanRig.Chest].x += 12f; tgt[HumanRig.Neck].x -= 10f;
                aL = new Vector3(-25f + s * 10f * move, 0, -8f); aR = new Vector3(-25f - s * 10f * move, 0, 8f);
                eL = eR = new Vector3(-35f, 0, 0);
                break;
            case AnimStyle.Burning:
                aL = new Vector3(s * armAmp * 0.6f - 10f, 0, -28f); aR = new Vector3(-s * armAmp * 0.6f - 10f, 0, 28f);
                eL = eR = new Vector3(-40f, 0, 0);
                break;
        }
        // удар рукой
        if (attackW > 0.001f)
        {
            float a = Mathf.Clamp01(attack01);
            float wind = Mathf.Sin(Mathf.Min(1f, a / 0.35f) * Mathf.PI * 0.5f);
            float strike = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(0.35f, 0.6f, a));
            Vector3 atkR = Vector3.Lerp(new Vector3(-150f * wind, 0, 40f * wind), new Vector3(-40f, 0, -10f), strike);
            Vector3 atkL = Vector3.Lerp(new Vector3(-60f * wind, 0, -20f), new Vector3(-110f, 0, -15f), strike);
            aR = Vector3.Lerp(aR, atkR, attackW); aL = Vector3.Lerp(aL, atkL, attackW * 0.6f);
            eR = Vector3.Lerp(eR, new Vector3(-80f * (1f - strike) - 10f, 0, 0), attackW);
            tgt[HumanRig.Spine].x += 12f * strike * attackW;
            tgt[HumanRig.Chest].y += (-25f * wind + 35f * strike) * attackW;
        }
        // бросок гранаты (правая рука)
        if (throwW > 0.001f)
        {
            float a = Mathf.Clamp01(throw01);
            float wind = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(0f, 0.45f, a));
            float rel = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(0.45f, 0.7f, a));
            Vector3 tr = Vector3.Lerp(new Vector3(-140f * wind + 30f * wind, 0, 50f * wind), new Vector3(-70f, 0, -10f), rel);
            aR = Vector3.Lerp(aR, tr, throwW);
            eR = Vector3.Lerp(eR, new Vector3(-90f * (1f - rel), 0, 0), throwW);
            tgt[HumanRig.Chest].y += (-25f * wind + 40f * rel) * throwW;
            tgt[HumanRig.Spine].x += -8f * wind + 15f * rel;
        }
        // сидение — руки на коленях / на оружии
        if (seatW > 0.001f && gunW < 0.5f)
        {
            aL = Vector3.Lerp(aL, new Vector3(-45f, 0, -5f), seatW);
            aR = Vector3.Lerp(aR, new Vector3(-45f, 0, 5f), seatW);
            eL = Vector3.Lerp(eL, new Vector3(-35f, 0, 0), seatW);
            eR = Vector3.Lerp(eR, new Vector3(-35f, 0, 0), seatW);
        }
        tgt[HumanRig.UArmL] = aL; tgt[HumanRig.UArmR] = aR;
        tgt[HumanRig.LArmL] = eL; tgt[HumanRig.LArmR] = eR;
        tgt[HumanRig.HandL] = new Vector3(-5f, 0, 0); tgt[HumanRig.HandR] = new Vector3(-5f, 0, 0);

        // голова — компенсирует наклон корпуса и смотрит в сторону цели
        tgt[HumanRig.Neck].x -= (tgt[HumanRig.Spine].x + tgt[HumanRig.Chest].x) * 0.35f;
        tgt[HumanRig.Head].x -= (tgt[HumanRig.Spine].x + tgt[HumanRig.Chest].x) * 0.3f + pitch * 0.5f;
        tgt[HumanRig.Head].y += yaw * 0.25f;
        tgt[HumanRig.Head].x = Mathf.Clamp(tgt[HumanRig.Head].x, -40f, 45f);
        if (rig.jaw != null) rig.jaw.localRotation = Quaternion.Euler(Mathf.Lerp(0, 40f, mouth), 0, 0);

        // реакция на попадание
        tgt[HumanRig.Spine] += flinch * 0.5f;
        tgt[HumanRig.Chest] += flinch * 0.6f;
        tgt[HumanRig.Head] += flinch * 0.4f;

        // ---------------- применение со сглаживанием ----------------
        float kRot = 14f;
        for (int i = 0; i < HumanRig.Count; i++)
        {
            Quaternion q = Quaternion.Euler(tgt[i]);
            float k = (i >= HumanRig.ULegL ? 22f : kRot);
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

        // ---------------- ОРУЖИЕ и IK рук ----------------
        PlaceGun(dt, time);
        SolveArms(dt, time);
    }

    void PlaceGun(float dt, float time)
    {
        if (gun == null) return;
        var t = gun.transform;
        bool pistol = gun.def.kind == WeaponKind.Pistol;
        bool rpg = gun.def.id == "rpg";
        Transform chest = rig.b[HumanRig.Chest];
        float tor = rig.shape.torso;
        Vector3 pivotLocal = pistol ? new Vector3(0.0f, 0.15f * tor, 0.05f) : rpg ? new Vector3(0.12f, 0.27f * tor, 0.0f) : new Vector3(0.1f, 0.16f * tor, 0.03f);
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
        // перезарядка — оружие наклоняется и опускается
        if (reloadW > 0.001f)
        {
            float r = Mathf.Clamp01(reload01);
            float tilt = Mathf.Sin(Mathf.Min(1f, r * 1.25f) * Mathf.PI);
            target = Quaternion.Slerp(target, transform.rotation * Quaternion.Euler(25f, -20f, 35f) * Quaternion.Euler(0, 0, 0), reloadW * tilt * 0.8f + reloadW * 0.2f);
        }
        if (throwW > 0.001f) target = Quaternion.Slerp(target, lowRot * Quaternion.Euler(20f, -20f, 0), throwW);
        target = Quaternion.Slerp(target, seatRot, seatW);
        // покачивание при ходьбе/дыхании
        float bob = Mathf.Sin(phase * 2f) * 1.5f * Mathf.Clamp01(spd / 3f);
        target = target * Quaternion.Euler(bob + kick.x + Mathf.Sin(time * 1.3f) * 0.6f, Mathf.Sin(phase) * 1.2f * Mathf.Clamp01(spd / 3f), 0);
        pivotRot = Quaternion.Slerp(pivotRot, target, 1f - Mathf.Exp(-(aiming ? 18f : 10f) * dt));
        Quaternion final = Quaternion.Slerp(pivotRot, ropeRot, 1f - gunW);

        Vector3 holdOffset = pistol ? new Vector3(0f, -0.02f, Mathf.Lerp(0.28f, 0.42f, aimW))
            : rpg ? new Vector3(0f, -0.08f, 0.05f)
            : new Vector3(0f, -0.03f, 0.2f + kick.z * 0.02f);
        Vector3 holdPos = rig.aimPivot.position + final * holdOffset * transform.lossyScale.y;
        Vector3 slingPos = chest.TransformPoint(new Vector3(0.05f, 0.12f * tor, -0.2f));
        t.position = Vector3.Lerp(slingPos, holdPos, gunW);
        t.rotation = final;
    }

    void SolveArms(float dt, float time)
    {
        var b = rig.b;
        float ikR = 0, ikL = 0;
        Vector3 tR = Vector3.zero, tL = Vector3.zero;
        Quaternion rR = Quaternion.identity, rL = Quaternion.identity;
        Vector3 right = transform.right, down = -transform.up, back = -transform.forward;

        if (gun != null && gunW > 0.01f)
        {
            var gt = gun.transform;
            rR = gt.rotation * Quaternion.Euler(-75f, 0f, -15f);
            tR = gun.grip.position + rR * new Vector3(0, 0.065f, 0) * transform.lossyScale.y;
            ikR = gunW * (1f - throwW);
            rL = gt.rotation * Quaternion.Euler(-60f, 0f, 75f);
            Vector3 fore = gun.foregrip.position + rL * new Vector3(0, 0.06f, 0) * transform.lossyScale.y;
            tL = fore;
            ikL = gunW;
            // перезарядка: левая рука к магазину, к подсумку и обратно
            if (reloadW > 0.01f && gun.mag != null)
            {
                float r = Mathf.Clamp01(reload01);
                Vector3 magPos = gun.transform.TransformPoint(gun.magRest);
                Vector3 pouch = b[HumanRig.Hips].TransformPoint(new Vector3(-0.15f, 0.05f, 0.12f));
                Vector3 p;
                if (r < 0.2f) p = Vector3.Lerp(fore, magPos, Mathf.SmoothStep(0, 1, r / 0.2f));
                else if (r < 0.45f) p = Vector3.Lerp(magPos, pouch, Mathf.SmoothStep(0, 1, (r - 0.2f) / 0.25f));
                else if (r < 0.7f) p = Vector3.Lerp(pouch, magPos, Mathf.SmoothStep(0, 1, (r - 0.45f) / 0.25f));
                else p = Vector3.Lerp(magPos, fore, Mathf.SmoothStep(0, 1, (r - 0.7f) / 0.3f));
                tL = Vector3.Lerp(fore, p, reloadW);
                // магазин следует за рукой
                if (r > 0.2f && r < 0.7f) gun.mag.position = b[HumanRig.HandL].position + b[HumanRig.HandL].rotation * new Vector3(0, -0.08f, 0);
                else gun.mag.localPosition = gun.magRest;
                if (gun.pump != null) gun.pump.localPosition = gun.pumpRest + new Vector3(0, 0, -0.08f * Mathf.Sin(r * Mathf.PI * 4f));
            }
            else if (gun.mag != null && gun.mag.localPosition != gun.magRest) gun.mag.localPosition = gun.magRest;
        }
        // канат: обе руки над головой
        if (ropeW > 0.01f)
        {
            Vector3 top = new Vector3(ropePoint.x, b[HumanRig.Head].position.y + 0.25f, ropePoint.z);
            tR = Vector3.Lerp(tR, top + Vector3.up * 0.08f, ropeW); ikR = Mathf.Max(ikR, ropeW);
            tL = Vector3.Lerp(tL, top - Vector3.up * 0.18f, ropeW); ikL = Mathf.Max(ikL, ropeW);
            rR = Quaternion.Slerp(rR, transform.rotation * Quaternion.Euler(180f, 0, 0), ropeW);
            rL = Quaternion.Slerp(rL, transform.rotation * Quaternion.Euler(180f, 0, 0), ropeW);
        }
        // руки на лице (SCP-096 плачет)
        if (faceW > 0.01f)
        {
            var h = b[HumanRig.Head];
            Vector3 f = h.TransformPoint(new Vector3(0, 0.12f, 0.2f));
            tR = Vector3.Lerp(tR, f + h.right * 0.05f, faceW); ikR = Mathf.Max(ikR, faceW);
            tL = Vector3.Lerp(tL, f - h.right * 0.05f, faceW); ikL = Mathf.Max(ikL, faceW);
            rR = h.rotation * Quaternion.Euler(170f, 0, 15f);
            rL = h.rotation * Quaternion.Euler(170f, 0, -15f);
        }

        Vector3 scale = transform.lossyScale;
        if (ikR > 0.01f)
        {
            Vector3 pole = b[HumanRig.UArmR].position + (down * 0.5f + right * 0.45f + back * 0.15f) * scale.y;
            TwoBone(b[HumanRig.UArmR], b[HumanRig.LArmR], b[HumanRig.HandR], tR, pole, ikR);
            b[HumanRig.HandR].rotation = Quaternion.Slerp(b[HumanRig.HandR].rotation, rR, ikR);
        }
        if (ikL > 0.01f)
        {
            Vector3 pole = b[HumanRig.UArmL].position + (down * 0.6f - right * 0.35f + back * 0.1f) * scale.y;
            TwoBone(b[HumanRig.UArmL], b[HumanRig.LArmL], b[HumanRig.HandL], tL, pole, ikL);
            b[HumanRig.HandL].rotation = Quaternion.Slerp(b[HumanRig.HandL].rotation, rL, ikL);
        }
    }

    // Аналитический IK двух звеньев. Кость направлена по -Y, сгиб — вперёд (+Z).
    public static void TwoBone(Transform a, Transform b, Transform c, Vector3 target, Vector3 pole, float w)
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
        Vector3 up1 = (A - elbow).normalized;
        Vector3 f1 = Vector3.ProjectOnPlane(-perp, up1);
        if (f1.sqrMagnitude < 1e-6f) f1 = a.forward;
        Quaternion qa = Quaternion.LookRotation(f1.normalized, up1);
        Vector3 up2 = (elbow - hand).normalized;
        Vector3 f2 = Vector3.ProjectOnPlane(-perp, up2);
        if (f2.sqrMagnitude < 1e-6f) f2 = b.forward;
        Quaternion qb = Quaternion.LookRotation(f2.normalized, up2);
        Quaternion cRot = c.rotation;
        a.rotation = Quaternion.Slerp(a.rotation, qa, w);
        b.rotation = Quaternion.Slerp(b.rotation, qb, w);
        c.rotation = cRot;
    }
}
