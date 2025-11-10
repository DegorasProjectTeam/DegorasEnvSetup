/***********************************************************************************************************************
 *  Copyright (C) 2025 Degoras Project Team
 *
 *  Authors:
 *      Ángel Vera Herrera       <avera@roa.es>   |  <angelvh.engr@gmail.com>
 *      Jesús Relinque Madroñal
 *
 *  Licensed under the MIT License.
 **********************************************************************************************************************/

/***********************************************************************************************************************
 *   HelloWorldQtMV – Minimal Qt Model-View example
 **********************************************************************************************************************/

// QT INCLUDES
#include <QApplication>
#include <QThread>

// PROJECT INCLUDES
#include "view.h"
#include "model.h"

/**
 * @brief Main entry point of the App_HelloWorldQtMV application.
 */
int main(int argc, char** argv)
{
    QApplication app(argc, argv);
	
	// View in GUI thread.
    View view;
	
	// Model in model thread.
	QThread model_thread;
    Model* model = new Model;                

	// Move to the model thread.
	model->moveToThread(&model_thread);

    // Connections UI <- Model
    QObject::connect(model, &Model::var1TextChanged, &view, &View::setVar1Text);
    QObject::connect(model, &Model::var2TextChanged, &view, &View::setVar2Text);
    QObject::connect(model, &Model::statusTextChanged, &view, &View::setStatusText);
	
	// Connections UI -> Model (Auto/Queued)
    QObject::connect(&view, &View::shortActionButtonClicked, model, &Model::shortActionReq);
    QObject::connect(&view, &View::longActionButtonClicked, model, &Model::longActionReq);

	// Clean.
    QObject::connect(&model_thread, &QThread::finished, model, &QObject::deleteLater);
	
	// Exit
	QObject::connect(&app, &QGuiApplication::lastWindowClosed, model, &Model::requestStop);
    QObject::connect(&app, &QGuiApplication::lastWindowClosed, &model_thread, &QThread::requestInterruption);
    QObject::connect(&app, &QCoreApplication::aboutToQuit, &model_thread, &QThread::quit);
	
	// Start the thread.
    model_thread.start();

	// Show.
    view.show();
    const int ret = app.exec();
	
    // Thread close.
    model_thread.wait();

	// Return.
    return ret;
}

// =====================================================================================================================