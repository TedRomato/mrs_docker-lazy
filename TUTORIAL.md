# UVDAR Experiment — Step-by-Step Tutorial

## Prerequisites

Install the following on your **laptop**:

- [Docker](https://docs.docker.com/engine/install/)
- [LazyDocker](https://github.com/jesseduffield/lazydocker)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- [Tmuxinator](https://github.com/tmuxinator/tmuxinator)

---

## 1. One-time drone setup

### 1.1 Copy SSH keys

```bash
cp mrs_docker-lazy/ssh/ansible ~/.ssh/ansible
cp mrs_docker-lazy/ssh/ansible.pub ~/.ssh/ansible.pub
chmod 600 ~/.ssh/ansible
```

### 1.2 Push the public key to each drone

```bash
ssh-copy-id -i ~/.ssh/ansible uav@192.168.69.163   # observer
ssh-copy-id -i ~/.ssh/ansible uav@192.168.69.164   # flier
```

### 1.3 Install Docker on each drone

SSH into each drone and run the scripts from `mrs_docker-lazy/install/`:

```bash
./docker-install.sh
./docker-host-settings.sh
./date.sh
```

### 1.4 Update inventory.ini

Edit `mrs_docker-lazy/inventory.ini` to match your drones' IPs:

```ini
[remote]
192.168.69.163 ansible_user=uav   # observer
192.168.69.164 ansible_user=uav   # flier
```

---

## 2. Update configuration

Before building, verify these files are correct.

### 2.1 Flight location & safety

- `shared_data_gnss/shared_data/shared_data/world_local.yaml` — GPS origin and **safety area** for your flying location. Pay attention to:
  - `origin_x` / `origin_y` — GPS coordinates of the local origin
  - `max_z` / `min_z` — vertical safety bounds. **Make sure `max_z` is high enough for your observer position** (see 2.2)
  - Horizontal polygon — defines the allowed flying area

### 2.2 Camera position & FOV parameters

Edit `shared_data_gnss/shared_data/shared_data/fov_flight.yaml`:

```yaml
C:         [-4.04, -3.71, 11.12]   # observer camera 3D position [x, y, z] meters
C_heading: 0.0                     # observer yaw [rad]
P_tl: [9.10, -4.33, 16.93]        # FOV corner: top-left ray endpoint
P_br: [-15.42, -7.34, 4.11]       # FOV corner: bottom-right ray endpoint
distance_min: 6.0                  # min sampling distance from observer
distance_max: 15.0                 # max sampling distance from observer
min_z: 5.0                         # minimum altitude for flier targets
target_radius: 0.25                # meters — flier considers target reached
```

**Important:** You must determine `C`, `C_heading`, `P_tl`, and `P_br` based on where you place the observer and the actual camera field of view. The flier will sample random targets inside the frustum defined by these points. Set `distance_min`/`distance_max`/`min_z` to keep the flier in a safe and useful range.

**Warning:** `C[2]` (observer altitude = 11.12m) must be **below `max_z`** in `world_local.yaml`. If `max_z` is 10.0 the goto will be rejected. Either raise `max_z` or lower `C[2]`.

### 2.3 MRS system tuning

- `shared_data_gnss/shared_data/shared_data/custom_config.yaml` — takeoff height (default 10m), controllers, mass estimator
- `shared_data_gnss/shared_data/shared_data/automatic_start.yaml` — preflight speed check
- `shared_data_gnss/shared_data/shared_data/network_config.yaml` — multi-UAV networking

### 2.4 UAV identity

- `stacks/stack_observer/stack.env` — observer UAV name/ID (e.g. `UAV_NAME=uav63`, `UAV_ID=_uav63`)
- `stacks/stack_flier/stack.env` — flier UAV name/ID (e.g. `UAV_NAME=uav64`, `UAV_ID=_uav64`)
- `tmux_session/session.yml` — IPs must match your drones

---

## 3. Pre-camp preparation (build images at home)

You can build and export all images on your laptop before going to the field.
Only the Ansible load step (section 4) needs network access to the drones.

**Verify architecture** in these files (should be `amd64` for Intel NUC):
- `catkin_workspace_uvdar/common_vars.sh` → `export ARCH=amd64`
- `shared_data_gnss/build_image.sh` → `ARCH=amd64`
- `load_custom_config/build_image.sh` → `ARCH=amd64`

### 3.1 Build & export the UVDAR workspace (slowest — compiles C++)

```bash
cd mrs_docker-lazy/catkin_workspace_uvdar
./build_image.sh
./export_image.sh
```

### 3.2 Build & export shared data (configs + scripts — fast)

```bash
cd mrs_docker-lazy/shared_data_gnss
./build_image.sh
./export_image.sh
```

### 3.3 Build & export UAV custom files (per-drone configs — fast)

```bash
cd mrs_docker-lazy/load_custom_config
./build_image.sh
./export_image.sh
```

After these, you'll have three tarballs in `~/docker/`:
- `uvdar_workspace:1.0.1.tar.gz`
- `shared_data:worlds.tar.gz`
- `uav_custom_files:uvdar.tar.gz`

> If you change any config after building, re-run only the relevant
> `build_image.sh` + `export_image.sh`.

---

## 4. At the camp — deploy images to drones

Once on the same network as the drones, load the pre-built images:

```bash
cd mrs_docker-lazy/catkin_workspace_uvdar && cd images_loader && ./load_image.sh && cd ../..
cd shared_data_gnss && cd images_loader && ./load_image.sh && cd ../..
cd load_custom_config && cd images_loader && ./load_image.sh && cd ../..
```

Each step will ask for the sudo password on the drone.

> `ctumrs/mrs_uav_system:1.5.1` and `klaxalk/dogtail:latest` are pulled
> automatically from Docker Hub the first time you run `./up.sh`.
> The drone needs internet access on first launch.

---

## 5. On-site checklist (before flying)

Verify these items at the field before starting the experiment:

- [ ] **GPS lock** — drones need GPS for the `gps_baro` state estimator. Wait for solid lock before starting.
- [ ] **Camera type** — the observer compose defaults to `rw_three_sided.launch`. If the observer has **Basler cameras**, edit `stacks/stack_observer/compose.yaml` and change the `uvdar` service command to use `rw_three_sided_basler.launch`.
- [ ] **Camera count** — verify how many UV cameras are mounted (2 or 3). Currently `record_observer.sh` only records `camera_front/image_raw`. Add other camera topics if needed.
- [ ] **LED board** — verify the flier's UV LED board is connected and the `UVDAR_ID` in `set_ids.sh` matches the physical configuration.
- [ ] **Safety area** — verify `world_local.yaml` GPS origin and safety polygon match the actual field. Make sure `max_z` accommodates the observer altitude in `fov_flight.yaml`.
- [ ] **Observer position** — update `C`, `C_heading`, `P_tl`, `P_br` in `fov_flight.yaml` based on where you want the observer to hover and the actual camera FOV.
- [ ] **Sampling range** — adjust `distance_min`, `distance_max`, `min_z` in `fov_flight.yaml` so the flier targets stay within the safety area and camera view.
- [ ] **UAV names** — confirm `stack.env` files match the assigned drone IDs.
- [ ] **Network** — drones reachable at the IPs in `inventory.ini`. Test with `ping`.

> If you change any config after deploying, re-run the relevant
> `build_image.sh` + `export_image.sh` + `load_image.sh`.

---

## 6. Start the experiment

### 6.1 Open the tmux session

```bash
cd mrs_docker-lazy/tmux_session
./start.sh
```

Two panes open:
- **Left pane** → observer drone (`DOCKER_HOST=tcp://192.168.69.163:2375`)
- **Right pane** → flier drone (`DOCKER_HOST=tcp://192.168.69.164:2375`)

### 6.2 Start the flier stack (right pane)

```bash
cd ~/git/mrs_docker-lazy/stacks/stack_flier
./up.sh
```

### 6.3 Start the observer stack (left pane)

```bash
cd ~/git/mrs_docker-lazy/stacks/stack_observer
./up.sh
```

### 6.4 Automatic boot sequence

After `./up.sh`, the following happens **automatically** on each drone:

1. Init containers copy files into Docker volumes
2. `roscore` starts → `rostime` sets `use_sim_time=false`
3. `hw_api` connects to PX4
4. `uav_core` starts the MRS control pipeline
5. `automatic_start` runs preflight checks → **auto-arms and takes off to 10m**
6. `rosbag` **starts recording automatically** (no manual start needed)
7. Flier: `led_manager` starts UV LED blinking
8. Observer: `cameras` start → `uvdar` detection pipeline starts
9. `rosbridge` starts WebSocket server

**Both rosbag services start automatically.** You do not need to start recording manually.

Monitor with LazyDocker (optional):

```bash
LAZYDOCKER_DIR=~/git/mrs_docker-lazy/lazydocker lazydocker
```

### 6.5 Send observer to camera position (manual — left pane)

Wait for the observer to take off and stabilize, then:

```bash
docker exec -it stack_observer-terminal-1 bash
source /etc/docker/catkin_workspace_1/devel/setup.bash
cd /etc/docker/shared_data
python3 observer_node.py
```

This sends the observer to position `C` defined in `fov_flight.yaml` and holds.

### 6.6 Start the flier experiment (manual — right pane)

**Wait for the observer to reach its position**, then:

```bash
docker exec -it stack_flier-terminal-1 bash
source /etc/docker/catkin_workspace_1/devel/setup.bash
cd /etc/docker/shared_data
python3 random_flier_node.py
```

This continuously samples random points inside the camera FOV frustum and
sends goto commands to the flier. It keeps running until you Ctrl+C.

---

## 7. Extract rosbag data

**You must extract bags BEFORE stopping the experiment.** Running `./down.sh`
destroys the Docker volumes and all recorded data is permanently lost.

### Extract bags from the observer drone

From the **left pane** (or any terminal with observer's DOCKER_HOST):

```bash
export DOCKER_HOST=tcp://192.168.69.163:2375
mkdir -p /tmp/observer_bags

# Copy bags from the Docker volume to the drone's /tmp
docker run --rm \
  -v stack_observer_bag_files:/bags:ro \
  -v /tmp/observer_bags:/out \
  alpine sh -c "cp /bags/* /out/"

# Copy from the drone to your laptop
unset DOCKER_HOST
scp -i ~/.ssh/ansible uav@192.168.69.163:/tmp/observer_bags/* ~/data/observer/
```

### Extract bags from the flier drone

From the **right pane** (or any terminal with flier's DOCKER_HOST):

```bash
export DOCKER_HOST=tcp://192.168.69.164:2375
mkdir -p /tmp/flier_bags

docker run --rm \
  -v stack_flier_bag_files:/bags:ro \
  -v /tmp/flier_bags:/out \
  alpine sh -c "cp /bags/* /out/"

unset DOCKER_HOST
scp -i ~/.ssh/ansible uav@192.168.69.164:/tmp/flier_bags/* ~/data/flier/
```

---

## 8. Stop the experiment

**Only after extracting bags** (section 7), in each tmux pane:

```bash
./down.sh
```

> **Warning:** `down.sh` removes all Docker volumes (`-v` flag).
> Any bags not extracted will be permanently deleted.

---

## Quick reference — what to re-run when things change

| What changed | Command to re-run |
|---|---|
| UVDAR source code (`src/uvdar_core`) | `catkin_workspace_uvdar/build_image.sh` + `export_image.sh` + `images_loader/load_image.sh` |
| Experiment scripts, configs, world files | `shared_data_gnss/build_image.sh` + `export_image.sh` + `images_loader/load_image.sh` |
| Camera calibration, LED IDs | `load_custom_config/build_image.sh` + `export_image.sh` + `images_loader/load_image.sh` |
| MRS system version | Update `MRS_UAV_SYSTEM_VERSION` in `stack.env` (drone pulls new version automatically) |
| Drone IP or role assignment | Edit `inventory.ini`, `stack.env`, `session.yml` |
| Compose services | Edit `compose.yaml`, then `./down.sh && ./up.sh` |







// drone
sudo systemctl restart docker.service

// local docker
export ROS_MASTER_URI=http://192.168.69.114:11311

//local
docker rm registry
docker run -d -p 5000:5000 --name registry registry:2
docker push localhost:5000/alpine
export DOCKER_HOST=tcp://192.168.69.114:2375; - AFTER the previous command!!!! 

-> compose after

 





export ROS_MASTER_URI=http://localhost:11311
export ROS_HOSTNAME=localhost