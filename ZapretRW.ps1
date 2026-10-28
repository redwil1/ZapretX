Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Windows.Forms, System.Drawing

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$favFile = Join-Path $root "favorites.txt"
$logFile = Join-Path $root "log.txt"

trap {
    $msg = "[{0}] CRASH: {1}`r`n{2}`r`n{3}" -f (Get-Date -Format "HH:mm:ss"), $_.Exception.ToString(), $_.ScriptStackTrace, $_.InvocationInfo.PositionMessage
    Add-Content -Path (Join-Path $root "crash.log") -Value $msg
    [System.Windows.MessageBox]::Show("Ошибка: $($_.Exception.Message)", "Zapret RW - crash") | Out-Null
    exit 1
}
Add-Content -Path (Join-Path $root "crash.log") -Value ("[{0}] script started" -f (Get-Date -Format "HH:mm:ss"))

$strategies = @(
    [PSCustomObject]@{ Id = 1; Name = "Классическая"; Desc = "YouTube/общие сайты, движок winws.exe"; Script = "strategy1.cmd"; Icon = "1" }
    [PSCustomObject]@{ Id = 2; Name = "Lua-движок";   Desc = "Та же цель, другой движок — пробовать, если 1 не помогла"; Script = "strategy2.cmd"; Icon = "2" }
    [PSCustomObject]@{ Id = 3; Name = "Только WireGuard"; Desc = "Узкий пресет, не трогает сайты — для VPN (AmneziaWG)"; Script = "strategy3.cmd"; Icon = "3" }
)

function Get-Favorites { if (Test-Path $favFile) { return @(Get-Content $favFile | Where-Object { $_ -ne "" }) }; return @() }
function Save-Favorites($list) { $list | Set-Content -Path $favFile }
function Write-Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
    Add-Content -Path $logFile -Value $line
    return $line
}
function Get-ActiveStrategyId {
    # No WMI/CIM — Win32_Service hung indefinitely here. Plain SCM check + a marker file.
    $running = (Get-Service -Name "ZapretRW" -ErrorAction SilentlyContinue).Status -eq "Running"
    if (-not $running) { return $null }
    $stateFile = Join-Path $root "active.txt"
    if (-not (Test-Path $stateFile)) { return $null }
    $idText = (Get-Content $stateFile -Raw -ErrorAction SilentlyContinue)
    if (-not $idText) { return $null }
    $id = 0
    if ([int]::TryParse($idText.Trim(), [ref]$id) -and ($strategies.Id -contains $id)) { return $id }
    return $null
}
$favorites = [System.Collections.Generic.List[string]](Get-Favorites)

function Color($hex) { [System.Windows.Media.ColorConverter]::ConvertFromString($hex) }
function Brush($hex) { New-Object System.Windows.Media.SolidColorBrush (Color $hex) }

$cBg = "#0B0B0C"; $cSurface = "#17171A"; $cSurface2 = "#202024"
$cText = "#F0EEEA"; $cMuted = "#8A8A90"; $cAccent = "#F0A83C"; $cDivider = "#2A2A2E"

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="zapret rw" Height="680" Width="420" ResizeMode="CanMinimize"
        WindowStartupLocation="CenterScreen" Background="#0B0B0C" FontFamily="Segoe UI">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="300"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="66"/>
    </Grid.RowDefinitions>

    <!-- HERO -->
    <Grid Grid.Row="0">
      <Grid.RowDefinitions>
        <RowDefinition Height="38"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>
      <DockPanel Grid.Row="0" Margin="22,12,22,0">
        <TextBlock x:Name="KickerText" Text="01 · ОБХОД DPI" FontSize="11" FontWeight="Bold" Foreground="#8A8A90" DockPanel.Dock="Left" VerticalAlignment="Center"/>
        <TextBlock x:Name="UptimeText" Text="00:00:00" FontSize="13" FontFamily="Consolas" FontWeight="Bold" Foreground="#8A8A90" DockPanel.Dock="Right" HorizontalAlignment="Right" VerticalAlignment="Center"/>
      </DockPanel>
      <Grid Grid.Row="1">
        <Ellipse x:Name="GlowEllipse" Width="300" Height="300" Opacity="0">
          <Ellipse.Fill>
            <RadialGradientBrush Center="0.5,0.5" GradientOrigin="0.5,0.5" RadiusX="0.5" RadiusY="0.5">
              <GradientStop Color="#55F0A83C" Offset="0"/>
              <GradientStop Color="#00F0A83C" Offset="1"/>
            </RadialGradientBrush>
          </Ellipse.Fill>
        </Ellipse>
        <Border x:Name="ToggleCircle" Width="180" Height="180" CornerRadius="90" Background="#17171A" BorderThickness="2" BorderBrush="#2A2A2E" Cursor="Hand">
          <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
            <TextBlock x:Name="ToggleIcon" Text="&#xE709;" FontFamily="Segoe MDL2 Assets" FontSize="34" Foreground="#F0EEEA" HorizontalAlignment="Center" Margin="0,0,0,10"/>
            <TextBlock x:Name="ToggleLabel" Text="ВКЛЮЧИТЬ" FontSize="13" FontWeight="Bold" Foreground="#F0EEEA" HorizontalAlignment="Center"/>
          </StackPanel>
        </Border>
      </Grid>
    </Grid>

    <!-- CONTENT (tabs swap this) -->
    <Grid Grid.Row="1" Margin="0,8,0,0">

      <!-- Home content -->
      <StackPanel x:Name="HomeContent" Orientation="Vertical" Margin="20,0,20,0">
        <Border Background="#17171A" CornerRadius="14" Padding="20,18">
          <StackPanel>
            <TextBlock Text="АКТИВНАЯ СТРАТЕГИЯ" FontSize="10" FontWeight="Bold" Foreground="#8A8A90"/>
            <TextBlock x:Name="StratValue" Text="Выключено" FontSize="22" FontWeight="Bold" Foreground="#F0EEEA" Margin="0,6,0,6" TextWrapping="Wrap"/>
            <TextBlock x:Name="StratDesc" Text="" FontSize="12" Foreground="#8A8A90" TextWrapping="Wrap"/>
          </StackPanel>
        </Border>
      </StackPanel>

      <!-- Processes content -->
      <StackPanel x:Name="ProcContent" Orientation="Vertical" Margin="20,0,20,0" Visibility="Collapsed">
        <TextBlock Text="Пробуй по очереди — какая реально работает у твоего провайдера, отмечай звёздочкой." FontSize="11" Foreground="#8A8A90" TextWrapping="Wrap" Margin="0,0,0,12"/>
        <StackPanel x:Name="StrategyList"/>
      </StackPanel>

      <!-- Settings content -->
      <StackPanel x:Name="SetContent" Orientation="Vertical" Margin="20,0,20,0" Visibility="Collapsed">
        <TextBlock Text="Zapret RW" FontSize="20" FontWeight="Bold" Foreground="#F0EEEA" Margin="0,0,0,10"/>
        <TextBlock Text="Ядро: официальный bol-van/zapret (проверено по контрольным суммам)." FontSize="12" Foreground="#C9C7C3" TextWrapping="Wrap" Margin="0,0,0,10"/>
        <TextBlock x:Name="FolderText" Text="" FontSize="11" FontFamily="Consolas" Foreground="#8A8A90" TextWrapping="Wrap" Margin="0,0,0,10"/>
        <TextBlock Text="Полное выключение: вкладка «Процессы» → «ОСТАНОВИТЬ» на активной стратегии." FontSize="12" Foreground="#C9C7C3" TextWrapping="Wrap"/>
      </StackPanel>

      <!-- Log content -->
      <Grid x:Name="LogContent" Margin="20,0,20,0" Visibility="Collapsed">
        <Border Background="#17171A" CornerRadius="14" Padding="2">
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <TextBlock x:Name="LogText" FontFamily="Consolas" FontSize="11" Foreground="#C9C7C3" Margin="14,10" TextWrapping="Wrap"/>
          </ScrollViewer>
        </Border>
      </Grid>
    </Grid>

    <!-- BOTTOM TAB BAR -->
    <Border Grid.Row="2" BorderThickness="0,1,0,0" BorderBrush="#2A2A2E">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/>
        </Grid.ColumnDefinitions>
        <StackPanel x:Name="Tab0" Grid.Column="0" VerticalAlignment="Center" HorizontalAlignment="Center" Cursor="Hand">
          <TextBlock x:Name="Tab0Icon" Text="&#xE80F;" FontFamily="Segoe MDL2 Assets" FontSize="18" HorizontalAlignment="Center" Foreground="#F0A83C"/>
          <TextBlock x:Name="Tab0Label" Text="Главная" FontSize="10" FontWeight="Bold" HorizontalAlignment="Center" Foreground="#F0A83C" Margin="0,3,0,0"/>
        </StackPanel>
        <StackPanel x:Name="Tab1" Grid.Column="1" VerticalAlignment="Center" HorizontalAlignment="Center" Cursor="Hand">
          <TextBlock x:Name="Tab1Icon" Text="&#xE9D9;" FontFamily="Segoe MDL2 Assets" FontSize="18" HorizontalAlignment="Center" Foreground="#8A8A90"/>
          <TextBlock x:Name="Tab1Label" Text="Процессы" FontSize="10" FontWeight="Bold" HorizontalAlignment="Center" Foreground="#8A8A90" Margin="0,3,0,0"/>
        </StackPanel>
        <StackPanel x:Name="Tab2" Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Center" Cursor="Hand">
          <TextBlock x:Name="Tab2Icon" Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="18" HorizontalAlignment="Center" Foreground="#8A8A90"/>
          <TextBlock x:Name="Tab2Label" Text="Настройки" FontSize="10" FontWeight="Bold" HorizontalAlignment="Center" Foreground="#8A8A90" Margin="0,3,0,0"/>
        </StackPanel>
        <StackPanel x:Name="Tab3" Grid.Column="3" VerticalAlignment="Center" HorizontalAlignment="Center" Cursor="Hand">
          <TextBlock x:Name="Tab3Icon" Text="&#xE8A5;" FontFamily="Segoe MDL2 Assets" FontSize="18" HorizontalAlignment="Center" Foreground="#8A8A90"/>
          <TextBlock x:Name="Tab3Label" Text="Журнал" FontSize="10" FontWeight="Bold" HorizontalAlignment="Center" Foreground="#8A8A90" Margin="0,3,0,0"/>
        </StackPanel>
      </Grid>
    </Border>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$kickerText = $window.FindName("KickerText")
$uptimeText = $window.FindName("UptimeText")
$glowEllipse = $window.FindName("GlowEllipse")
$toggleCircle = $window.FindName("ToggleCircle")
$toggleIcon = $window.FindName("ToggleIcon")
$toggleLabel = $window.FindName("ToggleLabel")
$homeContent = $window.FindName("HomeContent")
$procContent = $window.FindName("ProcContent")
$setContent = $window.FindName("SetContent")
$logContent = $window.FindName("LogContent")
$stratValue = $window.FindName("StratValue")
$stratDesc = $window.FindName("StratDesc")
$folderText = $window.FindName("FolderText")
$folderText.Text = "Папка программы:`r`n$root"
$strategyList = $window.FindName("StrategyList")
$logText = $window.FindName("LogText")
$tabs = @($window.FindName("Tab0"), $window.FindName("Tab1"), $window.FindName("Tab2"), $window.FindName("Tab3"))
$tabIcons = @($window.FindName("Tab0Icon"), $window.FindName("Tab1Icon"), $window.FindName("Tab2Icon"), $window.FindName("Tab3Icon"))
$tabLabels = @($window.FindName("Tab0Label"), $window.FindName("Tab1Label"), $window.FindName("Tab2Label"), $window.FindName("Tab3Label"))
$contents = @($homeContent, $procContent, $setContent, $logContent)

function Select-Tab($index) {
    for ($i = 0; $i -lt 4; $i++) {
        $contents[$i].Visibility = if ($i -eq $index) { "Visible" } else { "Collapsed" }
        $c = if ($i -eq $index) { Brush $cAccent } else { Brush $cMuted }
        $tabIcons[$i].Foreground = $c
        $tabLabels[$i].Foreground = $c
    }
    if ($index -eq 3 -and (Test-Path $logFile)) {
        $logText.Text = (Get-Content $logFile -Tail 80) -join "`r`n"
    }
}
for ($i = 0; $i -lt 4; $i++) {
    $tabs[$i].Add_MouseLeftButtonUp({ param($s, $e) Select-Tab ([array]::IndexOf($tabs, $s)) }.GetNewClosure())
}

# ── build the strategy cards (Процессы tab) ──
$script:strategyControls = @{}
foreach ($s in $strategies) {
    $card = New-Object System.Windows.Controls.Border
    $card.Background = Brush $cSurface
    $card.CornerRadius = [System.Windows.CornerRadius]::new(14)
    $card.Padding = [System.Windows.Thickness]::new(16,14,16,14)
    $card.Margin = [System.Windows.Thickness]::new(0,0,0,10)

    $grid = New-Object System.Windows.Controls.Grid
    $col1 = New-Object System.Windows.Controls.ColumnDefinition; $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $col2 = New-Object System.Windows.Controls.ColumnDefinition; $col2.Width = [System.Windows.GridLength]::Auto
    [void]$grid.ColumnDefinitions.Add($col1); [void]$grid.ColumnDefinitions.Add($col2)
    $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = [System.Windows.GridLength]::Auto
    $r2 = New-Object System.Windows.Controls.RowDefinition; $r2.Height = [System.Windows.GridLength]::Auto
    $r3 = New-Object System.Windows.Controls.RowDefinition; $r3.Height = [System.Windows.GridLength]::Auto
    [void]$grid.RowDefinitions.Add($r1); [void]$grid.RowDefinitions.Add($r2); [void]$grid.RowDefinitions.Add($r3)

    $nameRow = New-Object System.Windows.Controls.StackPanel
    $nameRow.Orientation = "Horizontal"
    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 9; $dot.Height = 9; $dot.Fill = Brush $cMuted; $dot.Margin = [System.Windows.Thickness]::new(0,0,8,0)
    $nameTb = New-Object System.Windows.Controls.TextBlock
    $nameTb.Text = $s.Name; $nameTb.FontSize = 15; $nameTb.FontWeight = "Bold"; $nameTb.Foreground = Brush $cText
    [void]$nameRow.Children.Add($dot); [void]$nameRow.Children.Add($nameTb)
    [System.Windows.Controls.Grid]::SetRow($nameRow, 0); [System.Windows.Controls.Grid]::SetColumn($nameRow, 0)
    [void]$grid.Children.Add($nameRow)

    $descTb = New-Object System.Windows.Controls.TextBlock
    $descTb.Text = $s.Desc; $descTb.FontSize = 11; $descTb.Foreground = Brush $cMuted
    $descTb.TextWrapping = "Wrap"; $descTb.Margin = [System.Windows.Thickness]::new(0,6,10,0)
    [System.Windows.Controls.Grid]::SetRow($descTb, 1); [System.Windows.Controls.Grid]::SetColumn($descTb, 0)
    [void]$grid.Children.Add($descTb)

    $btnRow = New-Object System.Windows.Controls.StackPanel
    $btnRow.Orientation = "Horizontal"; $btnRow.Margin = [System.Windows.Thickness]::new(0,10,0,0)
    $starBtn = New-Object System.Windows.Controls.Border
    $starBtn.Width = 34; $starBtn.Height = 30; $starBtn.CornerRadius = [System.Windows.CornerRadius]::new(8)
    $starBtn.Background = Brush $cSurface2; $starBtn.Cursor = "Hand"
    $starTb = New-Object System.Windows.Controls.TextBlock
    $starTb.Text = "&#x2606;"; $starTb.Text = [char]0x2606; $starTb.FontSize = 15; $starTb.HorizontalAlignment = "Center"; $starTb.VerticalAlignment = "Center"; $starTb.Foreground = Brush $cMuted
    $starBtn.Child = $starTb
    $tryBtn = New-Object System.Windows.Controls.Border
    $tryBtn.Height = 30; $tryBtn.CornerRadius = [System.Windows.CornerRadius]::new(8)
    $tryBtn.Background = Brush $cSurface2; $tryBtn.Cursor = "Hand"; $tryBtn.Margin = [System.Windows.Thickness]::new(8,0,0,0)
    $tryBtn.Padding = [System.Windows.Thickness]::new(16,0,16,0)
    $tryTb = New-Object System.Windows.Controls.TextBlock
    $tryTb.Text = "ПОПРОБОВАТЬ"; $tryTb.FontSize = 11; $tryTb.FontWeight = "Bold"; $tryTb.HorizontalAlignment = "Center"; $tryTb.VerticalAlignment = "Center"; $tryTb.Foreground = Brush $cText
    $tryBtn.Child = $tryTb
    [void]$btnRow.Children.Add($starBtn); [void]$btnRow.Children.Add($tryBtn)
    [System.Windows.Controls.Grid]::SetRow($btnRow, 2); [System.Windows.Controls.Grid]::SetColumn($btnRow, 0)
    [void]$grid.Children.Add($btnRow)

    $card.Child = $grid
    [void]$strategyList.Children.Add($card)

    $script:strategyControls[$s.Id] = @{ Dot = $dot; StarBtn = $starBtn; StarText = $starTb; TryBtn = $tryBtn; TryText = $tryTb; Strategy = $s }
}

function Get-DefaultStrategy {
    if ($favorites.Count -gt 0) {
        $f = $strategies | Where-Object { [string]$_.Id -eq $favorites[0] } | Select-Object -First 1
        if ($f) { return $f }
    }
    return $strategies[0]
}

$script:sinceOn = $null
function Refresh-All {
    $activeId = Get-ActiveStrategyId
    $isOn = [bool]$activeId

    if ($isOn) {
        $glowEllipse.Opacity = 1
        $kickerText.Foreground = Brush $cAccent
        $uptimeText.Foreground = Brush $cAccent
        $toggleCircle.BorderBrush = Brush $cAccent
        $toggleIcon.Foreground = Brush $cAccent
        $toggleLabel.Foreground = Brush $cAccent
        $toggleIcon.Text = [char]0xE709
        $toggleLabel.Text = "ПОДКЛЮЧЕНО"
        if (-not $script:sinceOn) { $script:sinceOn = Get-Date }
    } else {
        $glowEllipse.Opacity = 0
        $kickerText.Foreground = Brush $cMuted
        $uptimeText.Foreground = Brush $cMuted
        $toggleCircle.BorderBrush = Brush $cDivider
        $toggleIcon.Foreground = Brush $cText
        $toggleLabel.Foreground = Brush $cText
        $toggleIcon.Text = [char]0xE709
        $toggleLabel.Text = "ВКЛЮЧИТЬ"
        $script:sinceOn = $null
        $uptimeText.Text = "00:00:00"
    }

    $activeStrat = if ($activeId) { $strategies | Where-Object { $_.Id -eq $activeId } } else { $null }
    $stratValue.Text = if ($activeStrat) { $activeStrat.Name } else { "Выключено" }
    $stratValue.Foreground = if ($isOn) { Brush $cAccent } else { Brush $cText }
    $stratDesc.Text = if ($activeStrat) { $activeStrat.Desc } else { "Нажми круг выше, чтобы включить обход блокировок" }

    foreach ($id in $script:strategyControls.Keys) {
        $ctrl = $script:strategyControls[$id]
        $isActive = ($id -eq $activeId)
        $isFav = $favorites -contains [string]$id
        $ctrl.Dot.Fill = if ($isActive) { Brush $cAccent } else { Brush $cMuted }
        $ctrl.StarText.Text = if ($isFav) { [char]0x2605 } else { [char]0x2606 }
        $ctrl.StarText.Foreground = if ($isFav) { Brush $cAccent } else { Brush $cMuted }
        if ($isActive) {
            $ctrl.TryText.Text = "ОСТАНОВИТЬ"
            $ctrl.TryBtn.Background = Brush $cAccent
            $ctrl.TryText.Foreground = Brush $cBg
        } else {
            $ctrl.TryText.Text = "ПОПРОБОВАТЬ"
            $ctrl.TryBtn.Background = Brush $cSurface2
            $ctrl.TryText.Foreground = Brush $cText
        }
    }
}

function Toggle-Strategy($strategy) {
    if ((Get-ActiveStrategyId) -eq $strategy.Id) {
        Start-Process -FilePath (Join-Path $root "off.cmd") -Verb RunAs -Wait -WindowStyle Hidden
        Write-Log "Выключено: $($strategy.Name)" | Out-Null
    } else {
        Start-Process -FilePath (Join-Path $root $strategy.Script) -Verb RunAs -Wait -WindowStyle Hidden
        Write-Log "Включено: $($strategy.Name)" | Out-Null
    }
    Start-Sleep -Milliseconds 700
    Refresh-All
}

$toggleCircle.Add_MouseLeftButtonUp({
    $target = Get-DefaultStrategy
    Toggle-Strategy $target
})

foreach ($id in $script:strategyControls.Keys) {
    $ctrl = $script:strategyControls[$id]
    $ctrl.StarBtn.Add_MouseLeftButtonUp({
        param($s, $e)
        $sId = [string]($script:strategyControls.GetEnumerator() | Where-Object { $_.Value.StarBtn -eq $s }).Key
        if ($favorites -contains $sId) { [void]$favorites.Remove($sId) } else { $favorites.Add($sId) }
        Save-Favorites $favorites
        Refresh-All
    }.GetNewClosure())
    $ctrl.TryBtn.Add_MouseLeftButtonUp({
        param($s, $e)
        $match = $script:strategyControls.GetEnumerator() | Where-Object { $_.Value.TryBtn -eq $s }
        Toggle-Strategy $match.Value.Strategy
    }.GetNewClosure())
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    if ($script:sinceOn) {
        $span = (Get-Date) - $script:sinceOn
        $uptimeText.Text = $span.ToString("hh\:mm\:ss")
    }
})
$timer.Start()

# ── system tray: minimize-to-tray instead of sitting in the taskbar ──
function New-TrayIcon {
    $bmp = New-Object System.Drawing.Bitmap(32, 32)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 0x17, 0x17, 0x1A))
    $g.FillEllipse($bgBrush, 2, 2, 28, 28)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 0xF0, 0xA8, 0x3C)), 3
    $g.DrawEllipse($pen, 3, 3, 26, 26)
    $g.Dispose()
    return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = New-TrayIcon
$notifyIcon.Text = "Zapret RW"
$notifyIcon.Visible = $true

$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$miOpen = $trayMenu.Items.Add("Открыть")
$miToggle = $trayMenu.Items.Add("Включить/выключить")
[void]$trayMenu.Items.Add("-")
$miExit = $trayMenu.Items.Add("Выход")
$notifyIcon.ContextMenuStrip = $trayMenu

$script:reallyExit = $false
function Show-AppWindow {
    $window.Show()
    $window.WindowState = [System.Windows.WindowState]::Normal
    $window.Activate()
}
function Invoke-TrayToggle {
    if (Get-ActiveStrategyId) {
        Start-Process -FilePath (Join-Path $root "off.cmd") -Verb RunAs -Wait -WindowStyle Hidden
        Write-Log "Выключено (из трея)" | Out-Null
        Start-Sleep -Milliseconds 700
        Refresh-All
    } else {
        Toggle-Strategy (Get-DefaultStrategy)
    }
}

$miOpen.Add_Click({ Show-AppWindow })
$miToggle.Add_Click({ Invoke-TrayToggle })
$miExit.Add_Click({
    $script:reallyExit = $true
    $notifyIcon.Visible = $false
    $window.Close()
})
$notifyIcon.Add_DoubleClick({ Show-AppWindow })

$window.Add_StateChanged({
    if ($window.WindowState -eq [System.Windows.WindowState]::Minimized) { $window.Hide() }
})
$window.Add_Closing({
    param($s, $e)
    if (-not $script:reallyExit) {
        $e.Cancel = $true
        $window.Hide()
    } else {
        $notifyIcon.Visible = $false
    }
})

Select-Tab 0
Refresh-All
Add-Content -Path (Join-Path $root "crash.log") -Value ("[{0}] about to ShowDialog, apartment={1}" -f (Get-Date -Format "HH:mm:ss"), [System.Threading.Thread]::CurrentThread.GetApartmentState())
[void]$window.ShowDialog()
Add-Content -Path (Join-Path $root "crash.log") -Value ("[{0}] ShowDialog returned" -f (Get-Date -Format "HH:mm:ss"))




