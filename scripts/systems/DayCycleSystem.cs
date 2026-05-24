using Godot;

public enum DayPhase { Day, Night }

public class DayCycleSystem
{
    public DayPhase Phase { get; private set; } = DayPhase.Day;
    public int Stamina { get; private set; } = 5;
    public int MaxStamina { get; private set; } = 5;

    public event System.Action<DayPhase> PhaseChanged;
    public event System.Action StaminaChanged;

    public void StartDay()
    {
        Phase = DayPhase.Day;
        Stamina = MaxStamina;
        StaminaChanged?.Invoke();
    }

    public bool SpendStamina(int amount)
    {
        if (Phase != DayPhase.Day || Stamina < amount) return false;
        Stamina -= amount;
        StaminaChanged?.Invoke();
        return true;
    }

    public void NextPhase()
    {
        if (Phase == DayPhase.Day)
        {
            Phase = DayPhase.Night;
            PhaseChanged?.Invoke(Phase);
        }
        else
        {
            Phase = DayPhase.Day;
            StartDay();
            PhaseChanged?.Invoke(Phase);
        }
    }
}
