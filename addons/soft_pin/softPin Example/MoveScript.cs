using Godot;
using System;

public partial class MoveScript : Node3D
{
	[Export] AnimationPlayer animationPlayer;
	int animation = 0;
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
	}

    // Called every frame. 'delta' is the elapsed time since the previous frame.
    public override void _Process(double delta)
	{
		if (Input.IsActionPressed("left"))
		{
			GlobalPosition += new Vector3(-0.1f,0,0);
		}

        if (Input.IsActionPressed("left"))
        {
            GlobalPosition += Vector3.Zero;
        }

		switch (animation)
		{
			case 0:
			break;
		} 
    }
}
