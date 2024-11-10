defmodule Defender.Scenic.Ship do
  use GenServer

  @impl true
  def init(init_stats) do
    state = %{
      location: init_stats.location,
      velocity: init_stats.velocity
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_location, _from, state) do
    {:reply, state.location, state}
  end

  @impl true
  def handle_call(:get_state, _from, %{location: {x, y}, velocity: {vx, vy}} = state) do
    {:reply, %{ship_coords: { x, y }, ship_vel: {vx, vy} }, state}
  end

  @impl true
  def handle_call(:get_type, _from, state) do
    {:reply, :ship, state}
  end

  @impl true
  def handle_call({:update_location, time_step}, _from, %{location: {x, y}, velocity: {vx, vy}} = state) do
    new_location = { x + vx * time_step, y + vy * time_step }
    {:reply, new_location, Map.put(state, :location, new_location)}
  end

  @impl true
  def handle_call({:update_velocity, new_velocity}, _from, state) do
      {:reply, new_velocity, Map.put(state, :velocity, new_velocity)}
  end

end
