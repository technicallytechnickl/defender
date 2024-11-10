defmodule Defender.Scene.Home do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph

  import Scenic.Primitives
  # import Scenic.Components

  @note """
    This is a very simple starter application.

    If you want a more full-on example, please start from:

    mix scenic.new.example
  """

  @text_size 24
  @tile_radius 10
  @tile_size 10
  @frame_ms 192
  @graph Graph.build(font: :roboto, font_size: @text_size)
  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(scene, _param, _opts) do
    # get the width and height of the viewport. This is to demonstrate creating
    # a transparent full-screen rectangle to catch user input
    {width, height} = scene.viewport.size

    :ok = request_input(scene, [:key])

    #Assuming a square ship, how big is the vp in terms of ship tiles
    vp_tile_width = trunc(width / @tile_size)
    vp_tile_height = trunc(height / @tile_size)

    #Star the ship centered
    ship_start_coords = {
      trunc(vp_tile_width / 2),
      vp_tile_height - 10
    }

    #Create the game timer
    {:ok, timer} = :timer.send_interval(@frame_ms, :frame)

    {:ok, ship_pid} = GenServer.start_link(Defender.Scenic.Ship, %{location: ship_start_coords, velocity: {0,0}})
    # ship_start_state = %{ship: %{
    #                             ship_coords: ship_start_coords,
    #                             ship_vel: {0,0}
    #                             }
    #                       }

    graph =
      @graph
      |> draw_game_objects(%{ship: ship_pid})

      scene = scene
      |>assign(%{
        tile_width: vp_tile_width,
        tile_height: vp_tile_height,
        frame_timer: timer,
        frame_count: 1,
        graph: graph,
        objects: %{ship: ship_pid,
          bullets: []}
      })

    scene = push_graph(scene, graph)

    {:ok, scene}
  end

  def handle_info(:frame, scene) do

    new_graph = @graph
    |>draw_game_objects(scene.assigns.objects)

    IO.inspect(scene.assigns.objects, label: "scene")

    scene = scene
    |> move_objects()
    |>assign( graph: new_graph)
    |>push_graph(new_graph)

    {:noreply, scene}
  end

  defp move_objects(%Scenic.Scene{assigns: %{objects: object_map}} = scene) do
    new_object_map = Enum.reduce(object_map, %{}, fn {type, value} , acc ->
                      do_move_object(acc, type, value)
                    end)

    IO.inspect(new_object_map, label: "new_object_map")
    scene
    |>assign(objects: new_object_map)
  end

  defp do_move_object(object_map, :ship, pid) do
    #new_coords = {x + vx, y + vy}
    new_location = GenServer.call(pid, {:update_location, 1})
    Map.put(object_map, :ship, pid)
  end

  defp do_move_object(object_map, :bullets, pids) do
    #new_coords = {x + vx, y + vy}
    Enum.map(pids, fn pid ->
      new_location = GenServer.call(pid, {:update_location, 1}) end)
    Map.put(object_map, :bullets, pids)
  end

  defp draw_game_objects(graph, object_map) do
    Enum.reduce(object_map, graph, fn {type, value}, graph ->
      case type do
        :ship -> draw_object(graph, type, GenServer.call(value, :get_state))
        :bullets -> draw_object(graph, type, value)
      end
      end)
  end

  defp draw_object(graph, :ship, %{ship_coords: {x, y}, ship_vel: {_, _}}) do
    draw_tile(graph, x, y, fill: :lime)
  end

  defp draw_object(graph, :bullets, bullet_pids) do
    case bullet_pids do
      [] -> graph
      _ ->  Enum.reduce(bullet_pids, graph, fn pid, graph ->
              {x, y} = GenServer.call(pid, :get_location)
              draw_tile(graph, x, y, fill: :lime)
              end)
    end
  end

  defp draw_tile(graph, x, y, opts) do
    tile_opts = Keyword.merge([fill: :white, translate: {x * @tile_size, y * @tile_size}], opts)
    graph
    |> rounded_rectangle({@tile_size, @tile_size, @tile_radius}, tile_opts)
  end

  def handle_input({:key, {:key_left, 1, _}}, _context, scene) do
    IO.inspect("Left")
    {:noreply, update_ship_direction(scene, {-1, 0})}
  end

  def handle_input({:key, {:key_right, 1, _}}, _context, scene) do
    IO.inspect("Right")
    {:noreply, update_ship_direction(scene, {1, 0})}
  end

  def handle_input({:key, {:key_space, 1, _}}, _context, scene) do

    {:noreply, add_bullet(scene)}

  end

  defp add_bullet(scene) do
    ship_pid = scene.assigns.objects[:ship]
    %{ship_coords: { x, y }, ship_vel: {vx, vy} } = GenServer.call(ship_pid, :get_state)
    {:ok, bullet_pid} = GenServer.start_link(Defender.Scenic.Ship, %{location: {x, y}, velocity: {vx, vy - 1}})

    new_assigns = put_in(scene.assigns, [:objects, :bullets], [bullet_pid | scene.assigns.objects.bullets])

    scene
    |>assign(new_assigns)

  end


  defp update_ship_direction(scene, direction) do
    #new_objects = put_in(scene.assigns, [:objects, :ship, :ship_vel], direction)
    GenServer.call(scene.assigns.objects[:ship], {:update_velocity, direction})
    scene
  end

  def handle_input(event, _context, scene) do
    Logger.info("Received event: #{inspect(event)}")
    {:noreply, scene}
  end

end
