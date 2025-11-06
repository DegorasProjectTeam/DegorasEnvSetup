/***********************************************************************************************************************
 *  Copyright (C) 2025 Degoras Project Team
 *
 *  Authors:
 *      Ángel Vera Herrera       <avera@roa.es>   |  <angelvh.engr@gmail.com>
 *      Jesús Relinque Madroñal
 **********************************************************************************************************************/

/***********************************************************************************************************************
 *   AppHelloWorldQwt – Static + Animated Qwt + Qt Example
 **********************************************************************************************************************/

// C++ INCLUDES
#include <iostream>
#include <cmath>

// QT INCLUDES
#include <QApplication>
#include <QMainWindow>
#include <QTimer>
#include <QVBoxLayout>
#include <QPen>

// QWT INCLUDES
#include <qwt/qwt_plot.h>
#include <qwt/qwt_plot_curve.h>
#include <qwt/qwt_plot_grid.h>
#include <qwt/qwt_legend.h>
#include <qwt/qwt_text.h>

/**
 * @brief MainWindow hosting both static and animated Qwt plots.
 */
class MainWindow : public QMainWindow
{
    Q_OBJECT

public:

    explicit MainWindow(QWidget* parent = nullptr): 
        QMainWindow(parent),
        plot_(new QwtPlot(QwtText("HELLO QWT C++ EXAMPLE"))),
        curve_static_(new QwtPlotCurve("y = sin(x)")),
        curve_animated_(new QwtPlotCurve("y = sin(x + t)")),
        timer_(new QTimer(this)),
        phase_(0.0)
    {
        // Set background
        plot_->setCanvasBackground(Qt::white);

        // Add grid
        QwtPlotGrid* grid = new QwtPlotGrid();
        grid->setPen(Qt::gray, 0.0, Qt::DotLine);
        grid->attach(this->plot_);

        // Add legend
        QwtLegend* legend = new QwtLegend();
        this->plot_->insertLegend(legend, QwtPlot::BottomLegend);

        // Configure plot.
        plot_->setAxisScale(QwtPlot::yLeft, -1.6, 1.6);
        plot_->setAutoReplot(false);

        // Static curve setup
        this->curve_static_->setRenderHint(QwtPlotItem::RenderAntialiased);
        this->curve_static_->setPen(QPen(Qt::red, 2, Qt::SolidLine));
        this->curve_static_->attach(this->plot_);

        // Animated curve setup
        this->curve_animated_->setRenderHint(QwtPlotItem::RenderAntialiased);
        this->curve_animated_->setPen(QPen(Qt::blue, 2, Qt::DashLine));
        this->curve_animated_->attach(this->plot_);

        // Static data initialization
        constexpr int N = 200;
        QVector<double> x(N), y(N);
        for (int i = 0; i < N; ++i)
        {
            x[i] = i / 10.0;
            y[i] = std::sin(x[i]);
        }
        this->curve_static_->setSamples(x, y);

        // UI Setup
        QWidget* central = new QWidget();
        QVBoxLayout* layout = new QVBoxLayout(central);
        layout->addWidget(plot_);
        this->setCentralWidget(central);

        this->resize(800, 600);
        this->setWindowTitle("Hello QWT C++ Example – Static + Animated Sine");

        // Timer Setup for 120 Hz.
        this->timer_->setTimerType(Qt::PreciseTimer);
        this->connect(this->timer_, &QTimer::timeout, this, &MainWindow::updateAnimatedCurve);
        this->timer_->start(8);
    }

private slots:

    /**
     * @brief Update the animated sine curve.
     */
    void updateAnimatedCurve()
    {
        // Compute delta time (in seconds)
        qint64 now = elapsed_.elapsed();
        double dt = (now - last_frame_time_) / 1000.0;
        this->last_frame_time_ = now;

        // Update phase for wave motion
        constexpr double speed = 5.0; // rad/s
        this->phase_ += speed * dt;
        if (phase_ > 2 * M_PI)
            phase_ -= 2 * M_PI;

        // Amplitude modulation
        // Oscillates between minAmp and maxAmp using a low-frequency sine wave
        constexpr double ampSpeed = 0.5;      // cycles per second (Hz)
        constexpr double minAmp   = 0.5;
        constexpr double maxAmp   = 1.5;
        double t = elapsed_.elapsed() / 1000.0; // time in seconds
        double amplitude = minAmp + (maxAmp - minAmp) * (0.5 + 0.5 * std::sin(2 * M_PI * ampSpeed * t));

        // Recompute sine curve
        constexpr int N = 200;
        QVector<double> x(N), y(N);
        for (int i = 0; i < N; ++i)
        {
            x[i] = i / 10.0;
            y[i] = amplitude * std::sin(x[i] + phase_);
        }

        // Set samples and replot.
        this->curve_animated_->setSamples(x, y);
        this->plot_->replot();
    }

private:

    QwtPlot* plot_;
    QwtPlotCurve* curve_static_;
    QwtPlotCurve* curve_animated_;
    QTimer* timer_;
    QElapsedTimer elapsed_;
    qint64 last_frame_time_;
    double phase_;
};

/**
 * @brief Main entry point of the AppHelloWorldQwt application.
 */
int main(int argc, char** argv)
{
    std::cout << "==================================" << std::endl;
    std::cout << "= HELLO WORLD QWT C++ EXAMPLE    =" << std::endl;
    std::cout << "==================================" << std::endl;

    QApplication app(argc, argv);

    MainWindow window;
    window.show();

    return app.exec();
}

// Include mocs
#include "App_HelloWorldQwt.moc"

// =====================================================================================================================
