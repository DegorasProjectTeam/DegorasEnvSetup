
#include <iostream>
#include <random>
#include <thread>
#include <chrono>

#include <QThread>

#include "model.h"

Model::Model(QObject *parent) : 
	QObject{parent},
    var1_("Empty"),
    var2_("Empty"),
	stop_req_(false)
{}

void Model::shortActionReq()
{
	std::cout << "[Model] shortActionReq" << std::endl << std::flush;

    var1_ = QString::number(std::rand());
    var2_ = QString::number(std::rand());

    emit var1TextChanged(var1_);
    emit var2TextChanged(var2_);
}

void Model::longActionReq()
{
	std::cout << "[Model] longActionReq" << std::endl << std::flush;

    emit statusTextChanged("Processing long action...");

	// Cancelable wait
    for (int i = 0; i < 50; ++i) 
	{
        if (this->shouldStop()) 
		{
            emit statusTextChanged("Canceled.");
			std::cout << "[Model] longActionReq -> canceled" << std::endl << std::flush;
            return;
        }
        QThread::msleep(100);
    }


    static thread_local std::mt19937 rng{std::random_device{}()};
    std::uniform_int_distribution<int> dist(0, 999999);
    var1_ = QString::number(std::rand());
    var2_ = QString::number(std::rand());
	
	if (shouldStop()) 
	{  
        emit statusTextChanged("Canceled.");
		std::cout << "[Model] longActionReq -> canceled" << std::endl << std::flush;
        return;
    }

    emit var1TextChanged(var1_);
    emit var2TextChanged(var2_);

    emit statusTextChanged("Waiting user input...");
}

void Model::requestStop() noexcept
{ 
	std::cout << "[Model] requestStop" << std::endl << std::flush;
	stop_req_.store(true, std::memory_order_relaxed); 
}

Model::~Model() 
{
    std::cout << "[Model] Destructor started, simulating cleanup..." << std::endl << std::flush;
    // Simulate a long cleanup (e.g. closing resources)
    for (int i = 1; i <= 5; ++i)
    {
        std::cout << "[Model] Cleaning step" << i << std::endl << std::flush;
		std::this_thread::sleep_for(std::chrono::seconds(1));
    }
    std::cout << "[Model] Destructor finished." << std::endl << std::flush;
}

bool Model::shouldStop() const noexcept
{
    return stop_req_.load(std::memory_order_relaxed)
        || (QThread::currentThread() && QThread::currentThread()->isInterruptionRequested());
}